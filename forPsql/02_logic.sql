-- ============================================================================
-- PeopleMayLearn. Файл 2 из 4: бизнес-логика в базе данных
-- (функции, триггеры, представления). СУБД: PostgreSQL 16.
-- Запускать после 01_schema.sql.
-- ============================================================================
SET search_path TO pml;

-- ---------------------------------------------------------------------------
-- 1. Автопроверка ответа ученика (BEFORE INSERT ON attempt)
--    Числовые ответы сравниваются как числа (запятая = точка), строковые -
--    без учёта регистра и крайних пробелов.
-- ---------------------------------------------------------------------------
CREATE FUNCTION fn_attempt_check() RETURNS trigger AS $$
DECLARE
    t task%ROWTYPE;
BEGIN
    SELECT * INTO t FROM task WHERE task_id = NEW.task_id;
    IF t.answer_type = 'number' THEN
        BEGIN
            NEW.is_correct := replace(trim(NEW.answer), ',', '.')::numeric
                            = replace(trim(t.correct_answer), ',', '.')::numeric;
        EXCEPTION WHEN invalid_text_representation OR numeric_value_out_of_range THEN
            NEW.is_correct := false;
        END;
    ELSE
        NEW.is_correct := lower(trim(NEW.answer)) = lower(trim(t.correct_answer));
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SET search_path = pml;

CREATE TRIGGER trg_attempt_check
BEFORE INSERT ON attempt
FOR EACH ROW EXECUTE FUNCTION fn_attempt_check();

-- ---------------------------------------------------------------------------
-- 2. Пересчёт прогресса, XP и серии дней (AFTER INSERT ON attempt)
--    mastery_percent = доля верных попыток по теме;
--    тема «освоена» при >= 5 попыток и >= 80 % верных.
--    XP: +10 за верный ответ, +1 за неверный. Серия: решал вчера -> +1,
--    сегодня уже решал -> без изменений, иначе серия начинается с 1.
-- ---------------------------------------------------------------------------
CREATE FUNCTION fn_attempt_after() RETURNS trigger AS $$
DECLARE
    r        record;
    v_total  integer;
    v_ok     integer;
    v_pct    numeric(5,2);
    v_last   date;
    v_day    date;
BEGIN
    FOR r IN SELECT topic_id FROM task_topic WHERE task_id = NEW.task_id LOOP
        SELECT count(*), count(*) FILTER (WHERE a.is_correct)
          INTO v_total, v_ok
          FROM attempt a
          JOIN task_topic tt ON tt.task_id = a.task_id
         WHERE a.student_id = NEW.student_id AND tt.topic_id = r.topic_id;

        v_pct := ROUND(100.0 * v_ok / v_total, 2);

        INSERT INTO progress (student_id, topic_id, status, mastery_percent, updated_at)
        VALUES (NEW.student_id, r.topic_id,
                CASE WHEN v_total >= 5 AND v_pct >= 80
                     THEN 'mastered'::topic_status ELSE 'in_progress'::topic_status END,
                v_pct, now())
        ON CONFLICT (student_id, topic_id) DO UPDATE
           SET status          = EXCLUDED.status,
               mastery_percent = EXCLUDED.mastery_percent,
               updated_at      = EXCLUDED.updated_at;
    END LOOP;

    v_day := NEW.submitted_at::date;
    SELECT last_active_date INTO v_last FROM student_profile WHERE user_id = NEW.student_id;

    UPDATE student_profile
       SET xp = xp + CASE WHEN NEW.is_correct THEN 10 ELSE 1 END,
           streak_days = CASE WHEN v_last IS NOT NULL AND v_last >= v_day THEN streak_days
                              WHEN v_last = v_day - 1 THEN streak_days + 1
                              ELSE 1 END,
           last_active_date = GREATEST(COALESCE(v_last, v_day), v_day)
     WHERE user_id = NEW.student_id;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql SET search_path = pml;

CREATE TRIGGER trg_attempt_after
AFTER INSERT ON attempt
FOR EACH ROW EXECUTE FUNCTION fn_attempt_after();

-- ---------------------------------------------------------------------------
-- 3. Жизненный цикл занятия (BEFORE UPDATE OF status ON lesson)
--    planned -> in_progress | cancelled; in_progress -> completed;
--    completed -> calculated; calculated -> paid. Остальные переходы запрещены.
-- ---------------------------------------------------------------------------
CREATE FUNCTION fn_lesson_status() RETURNS trigger AS $$
BEGIN
    IF NEW.status = OLD.status THEN
        RETURN NEW;
    END IF;
    IF NOT (   (OLD.status = 'planned'     AND NEW.status IN ('in_progress', 'cancelled'))
            OR (OLD.status = 'in_progress' AND NEW.status = 'completed')
            OR (OLD.status = 'completed'   AND NEW.status = 'calculated')
            OR (OLD.status = 'calculated'  AND NEW.status = 'paid')) THEN
        RAISE EXCEPTION 'Недопустимый переход статуса занятия: % -> %', OLD.status, NEW.status;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SET search_path = pml;

CREATE TRIGGER trg_lesson_status
BEFORE UPDATE OF status ON lesson
FOR EACH ROW EXECUTE FUNCTION fn_lesson_status();

-- ---------------------------------------------------------------------------
-- 4. Расчёт завершённого занятия: списание с абонемента или счёт за разовое
--    Возвращает 'package' или 'single'.
-- ---------------------------------------------------------------------------
CREATE FUNCTION settle_lesson(p_lesson_id integer) RETURNS text AS $$
DECLARE
    l   lesson%ROWTYPE;
    pk  lesson_package%ROWTYPE;
BEGIN
    SELECT * INTO l FROM lesson WHERE lesson_id = p_lesson_id FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Занятие % не найдено', p_lesson_id;
    END IF;

    SELECT * INTO pk
      FROM lesson_package lp
     WHERE lp.tutor_id = l.tutor_id AND lp.student_id = l.student_id
       AND lp.lessons_left > 0
       AND lp.valid_until >= l.starts_at::date
       AND EXISTS (SELECT 1 FROM payment py
                    WHERE py.package_id = lp.package_id AND py.status = 'paid')
     ORDER BY lp.valid_until
     LIMIT 1
     FOR UPDATE;

    IF FOUND THEN
        UPDATE lesson
           SET status = 'calculated', package_id = pk.package_id,
               price = ROUND(pk.price / pk.lessons_total, 2)
         WHERE lesson_id = p_lesson_id;
        UPDATE lesson_package SET lessons_left = lessons_left - 1
         WHERE package_id = pk.package_id;
        UPDATE lesson SET status = 'paid' WHERE lesson_id = p_lesson_id;
        RETURN 'package';
    END IF;

    UPDATE lesson SET status = 'calculated' WHERE lesson_id = p_lesson_id;
    RETURN 'single';
END;
$$ LANGUAGE plpgsql SET search_path = pml;

-- ---------------------------------------------------------------------------
-- 5. Лимит учеников репетитора по тарифу (BEFORE INSERT ON tutor_student)
--    Без активной подписки действует бесплатный лимит: 3 ученика.
-- ---------------------------------------------------------------------------
CREATE FUNCTION fn_tutor_limit() RETURNS trigger AS $$
DECLARE
    v_limit  integer;
    v_active integer;
BEGIN
    IF NOT NEW.is_active THEN
        RETURN NEW;
    END IF;

    SELECT sp.max_students INTO v_limit
      FROM subscription s
      JOIN subscription_plan sp ON sp.plan_id = s.plan_id
     WHERE s.user_id = NEW.tutor_id AND s.status = 'active'
       AND sp.audience = 'tutor' AND s.ends_at >= current_date
     ORDER BY sp.price_month DESC
     LIMIT 1;
    IF NOT FOUND THEN
        v_limit := 3;                      -- бесплатный тариф
    END IF;

    SELECT count(*) INTO v_active
      FROM tutor_student WHERE tutor_id = NEW.tutor_id AND is_active;

    IF v_limit IS NOT NULL AND v_active >= v_limit THEN
        RAISE EXCEPTION 'Лимит учеников на тарифе исчерпан (%). Оформите подписку репетитора', v_limit;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SET search_path = pml;

CREATE TRIGGER trg_tutor_limit
BEFORE INSERT ON tutor_student
FOR EACH ROW EXECUTE FUNCTION fn_tutor_limit();

-- ---------------------------------------------------------------------------
-- 6. Доход платформы с платежа (BEFORE INSERT OR UPDATE ON payment)
--    Подписка - 100 % дохода платформы; оплата занятия или абонемента
--    между учеником и репетитором - комиссия 10 %.
-- ---------------------------------------------------------------------------
CREATE FUNCTION fn_payment_fee() RETURNS trigger AS $$
BEGIN
    IF NEW.kind = 'subscription' THEN
        NEW.platform_fee := NEW.amount;
    ELSE
        NEW.platform_fee := ROUND(NEW.amount * 0.10, 2);
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SET search_path = pml;

CREATE TRIGGER trg_payment_fee
BEFORE INSERT OR UPDATE OF amount, kind ON payment
FOR EACH ROW EXECUTE FUNCTION fn_payment_fee();

-- ---------------------------------------------------------------------------
-- 7. Реакция на успешную оплату (AFTER INSERT OR UPDATE OF status ON payment)
--    подписка: pending -> active; занятие: calculated -> paid.
-- ---------------------------------------------------------------------------
CREATE FUNCTION fn_payment_paid() RETURNS trigger AS $$
BEGIN
    IF NEW.status = 'paid' THEN
        IF TG_OP = 'UPDATE' THEN
            IF OLD.status = 'paid' THEN
                RETURN NULL;
            END IF;
        END IF;
        IF NEW.kind = 'subscription' THEN
            UPDATE subscription SET status = 'active'
             WHERE subscription_id = NEW.subscription_id AND status = 'pending';
        ELSIF NEW.kind = 'lesson' THEN
            UPDATE lesson SET status = 'paid'
             WHERE lesson_id = NEW.lesson_id AND status = 'calculated';
        END IF;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql SET search_path = pml;

CREATE TRIGGER trg_payment_paid
AFTER INSERT OR UPDATE OF status ON payment
FOR EACH ROW EXECUTE FUNCTION fn_payment_paid();

-- ---------------------------------------------------------------------------
-- 8. Есть ли у ученика действующая Premium-подписка на дату
-- ---------------------------------------------------------------------------
CREATE FUNCTION has_active_premium(p_user integer, p_on date DEFAULT current_date)
RETURNS boolean AS $$
    SELECT EXISTS (
        SELECT 1
          FROM subscription s
          JOIN subscription_plan sp ON sp.plan_id = s.plan_id
         WHERE s.user_id = p_user AND s.status = 'active'
           AND sp.audience = 'student'
           AND p_on BETWEEN s.started_at AND s.ends_at);
$$ LANGUAGE sql STABLE SET search_path = pml;

-- ---------------------------------------------------------------------------
-- 9. Представления
-- ---------------------------------------------------------------------------
-- Баланс ученика у репетитора: платежи минус стоимость проведённых занятий
CREATE VIEW v_student_balance AS
SELECT ts.tutor_id,
       ts.student_id,
       COALESCE(p.paid, 0)                          AS paid_total,
       COALESCE(c.cost, 0)                          AS lessons_cost,
       COALESCE(p.paid, 0) - COALESCE(c.cost, 0)    AS balance,
       COALESCE(k.lessons_left, 0)                  AS package_left
FROM tutor_student ts
LEFT JOIN (
    SELECT x.tutor_id, x.student_id, SUM(x.amount) AS paid
      FROM (SELECT l.tutor_id, l.student_id, py.amount
              FROM payment py JOIN lesson l ON l.lesson_id = py.lesson_id
             WHERE py.status = 'paid'
            UNION ALL
            SELECT lp.tutor_id, lp.student_id, py.amount
              FROM payment py JOIN lesson_package lp ON lp.package_id = py.package_id
             WHERE py.status = 'paid') x
     GROUP BY x.tutor_id, x.student_id) p
       ON p.tutor_id = ts.tutor_id AND p.student_id = ts.student_id
LEFT JOIN (
    SELECT tutor_id, student_id, SUM(price) AS cost
      FROM lesson
     WHERE status IN ('completed', 'calculated', 'paid')
     GROUP BY tutor_id, student_id) c
       ON c.tutor_id = ts.tutor_id AND c.student_id = ts.student_id
LEFT JOIN (
    SELECT tutor_id, student_id, SUM(lessons_left) AS lessons_left
      FROM lesson_package
     WHERE valid_until >= current_date
     GROUP BY tutor_id, student_id) k
       ON k.tutor_id = ts.tutor_id AND k.student_id = ts.student_id;

-- Доход платформы по месяцам и видам платежей
CREATE VIEW v_platform_revenue AS
SELECT date_trunc('month', paid_at)::date AS month,
       kind,
       count(*)           AS payments,
       SUM(amount)        AS gross,
       SUM(platform_fee)  AS platform_income
FROM payment
WHERE status = 'paid'
GROUP BY 1, 2;

-- «Слабые» темы учеников (освоение ниже 60 %)
CREATE VIEW v_weak_topics AS
SELECT p.student_id, u.full_name, t.title AS topic, p.mastery_percent
FROM progress p
JOIN topic t    ON t.topic_id = p.topic_id
JOIN app_user u ON u.user_id  = p.student_id
WHERE p.mastery_percent < 60;
