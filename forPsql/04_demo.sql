-- ============================================================================
-- PeopleMayLearn. Файл 4 из 4: демонстрационные сценарии (раздел 7.4 работы)
-- Запускать после 01-03, сценарии - строго по порядку 1-10 (они меняют данные).
-- Для повторного прогона заново выполните 01, 02 и 03.
-- Отказы целостности ловятся блоками DO ... EXCEPTION и выводятся как NOTICE
-- (вкладка «Сообщения» в pgAdmin), поэтому скрипт не прерывается.
-- ============================================================================
SET search_path TO pml;

-- ===== Сценарий 1. Ученик решает задачи: автопроверка, прогресс, XP ==========
-- Волков Артём (user_id = 10) отправляет верный и неверный ответ на задачу 4
INSERT INTO attempt (student_id, task_id, answer) VALUES (10, 4, '36'), (10, 4, '35');

SELECT attempt_id, task_id, answer, is_correct
FROM attempt WHERE student_id = 10 ORDER BY attempt_id;

SELECT topic_id, status, mastery_percent FROM progress WHERE student_id = 10;
SELECT xp, streak_days FROM student_profile WHERE user_id = 10;

-- ===== Сценарий 2. Каталог задач и Premium ===================================
SELECT u.full_name, count(*) AS available_tasks
FROM app_user u
JOIN task t ON t.is_published AND (t.access = 'free' OR has_active_premium(u.user_id, DATE '2026-11-26'))
WHERE u.user_id IN (10, 11)
GROUP BY u.full_name
ORDER BY u.full_name;

-- ===== Сценарий 3. Покупка Premium-подписки ==================================
INSERT INTO subscription (user_id, plan_id, started_at, ends_at)
VALUES (10, 1, current_date, current_date + 30);

INSERT INTO payment (payer_id, kind, amount, subscription_id)
SELECT 10, 'subscription'::payment_kind, sp.price_month, s.subscription_id
FROM subscription s JOIN subscription_plan sp ON sp.plan_id = s.plan_id
WHERE s.user_id = 10 AND s.status = 'pending';

-- платёжный шлюз подтвердил оплату (в макете - имитация)
UPDATE payment SET status = 'paid', paid_at = TIMESTAMPTZ '2026-12-05 12:00+03'
WHERE payer_id = 10 AND kind = 'subscription' AND status = 'pending';

SELECT s.subscription_id, s.status AS subscription_status, s.ends_at - s.started_at AS days,
       p.amount, p.platform_fee, p.status AS payment_status
FROM subscription s JOIN payment p ON p.subscription_id = s.subscription_id
WHERE s.user_id = 10;

SELECT has_active_premium(10) AS premium_now;

-- ===== Сценарий 4. Жизненный цикл занятия ====================================
SELECT lesson_id, status, price, package_id FROM lesson WHERE lesson_id = 3;
SELECT settle_lesson(3) AS payment_mode;
SELECT lesson_id, status, price, package_id FROM lesson WHERE lesson_id = 3;
SELECT package_id, lessons_total, lessons_left FROM lesson_package WHERE package_id = 1;

-- запрещённый переход: запланированное занятие нельзя сразу сделать оплаченным
DO $$
BEGIN
    UPDATE lesson SET status = 'paid' WHERE lesson_id = 7;
EXCEPTION WHEN others THEN
    RAISE NOTICE 'Отказ: %', SQLERRM;
END $$;

-- ===== Сценарий 5. Сквозной сценарий: занятие - расчёт - оплата ==============
INSERT INTO lesson (tutor_id, student_id, starts_at, price)
VALUES (2, 6, TIMESTAMPTZ '2026-12-10 15:00+03', 1000);           -- lesson_id = 11

UPDATE lesson SET status = 'in_progress' WHERE lesson_id = 11;
UPDATE lesson SET attendance = 'attended' WHERE lesson_id = 11;
UPDATE lesson SET status = 'completed'   WHERE lesson_id = 11;
SELECT settle_lesson(11) AS payment_mode;                          -- абонемента нет -> single

INSERT INTO payment (payer_id, kind, amount, lesson_id) VALUES (6, 'lesson', 1000, 11);
UPDATE payment SET status = 'paid', paid_at = TIMESTAMPTZ '2026-12-10 16:05+03'
WHERE lesson_id = 11;

SELECT l.lesson_id, l.status, l.attendance, l.price, p.status AS payment_status, p.platform_fee
FROM lesson l JOIN payment p ON p.lesson_id = l.lesson_id
WHERE l.lesson_id = 11;

-- ===== Сценарий 6. Баланс учеников ===========================================
SELECT b.tutor_id, b.student_id, u.full_name, b.paid_total, b.lessons_cost, b.balance, b.package_left
FROM v_student_balance b JOIN app_user u ON u.user_id = b.student_id
ORDER BY b.tutor_id, b.student_id;

-- ===== Сценарий 7. Тариф репетитора и лимит учеников =========================
-- у Смирновой Е.И. (user_id = 3) бесплатный тариф: лимит 3 ученика
DO $$
BEGIN
    INSERT INTO tutor_student (tutor_id, student_id, lesson_price) VALUES (3, 10, 1000);
EXCEPTION WHEN others THEN
    RAISE NOTICE 'Отказ: %', SQLERRM;
END $$;

INSERT INTO subscription (user_id, plan_id, started_at, ends_at)
VALUES (3, 2, current_date, current_date + 30);

INSERT INTO payment (payer_id, kind, amount, subscription_id)
SELECT 3, 'subscription'::payment_kind, sp.price_month, s.subscription_id
FROM subscription s JOIN subscription_plan sp ON sp.plan_id = s.plan_id
WHERE s.user_id = 3 AND s.status = 'pending';

UPDATE payment SET status = 'paid', paid_at = TIMESTAMPTZ '2026-12-05 13:00+03'
WHERE payer_id = 3 AND kind = 'subscription' AND status = 'pending';

INSERT INTO tutor_student (tutor_id, student_id, lesson_price) VALUES (3, 10, 1000);
SELECT count(*) AS active_students FROM tutor_student WHERE tutor_id = 3 AND is_active;

-- ===== Сценарий 8. Доход платформы ===========================================
SELECT month, kind, payments, gross, platform_income
FROM v_platform_revenue ORDER BY month, kind::text;

-- ===== Сценарий 9. Контроль целостности ======================================
-- (а) задача ЕГЭ без номера КИМ
DO $$ BEGIN
    INSERT INTO task (subject_id, exam, difficulty, statement, correct_answer)
    VALUES (1, 'ege', 3, 'Тестовая задача', '1');
EXCEPTION WHEN others THEN RAISE NOTICE 'Отказ (а): %', SQLERRM; END $$;

-- (б) занятие репетитора с чужим учеником (нет связи в tutor_student)
DO $$ BEGIN
    INSERT INTO lesson (tutor_id, student_id, starts_at, price)
    VALUES (3, 4, TIMESTAMPTZ '2026-12-20 10:00+03', 1000);
EXCEPTION WHEN others THEN RAISE NOTICE 'Отказ (б): %', SQLERRM; END $$;

-- (в) платёж за занятие, у которого указан абонемент вместо занятия
DO $$ BEGIN
    INSERT INTO payment (payer_id, kind, amount, lesson_id) VALUES (4, 'package', 100, 1);
EXCEPTION WHEN others THEN RAISE NOTICE 'Отказ (в): %', SQLERRM; END $$;

-- (г) вторая активная подписка у одного пользователя
DO $$ BEGIN
    INSERT INTO subscription (user_id, plan_id, started_at, ends_at, status)
    VALUES (11, 1, current_date, current_date + 30, 'active');
EXCEPTION WHEN others THEN RAISE NOTICE 'Отказ (г): %', SQLERRM; END $$;

-- (д) ответ на задачу, которой нет в указанном домашнем задании
DO $$ BEGIN
    INSERT INTO attempt (student_id, task_id, homework_id, answer) VALUES (4, 3, 1, '5');
EXCEPTION WHEN others THEN RAISE NOTICE 'Отказ (д): %', SQLERRM; END $$;

-- (е) два занятия у репетитора в одно и то же время
DO $$ BEGIN
    INSERT INTO lesson (tutor_id, student_id, starts_at, price)
    VALUES (2, 5, TIMESTAMPTZ '2026-11-03 17:00+03', 1200);
EXCEPTION WHEN others THEN RAISE NOTICE 'Отказ (е): %', SQLERRM; END $$;

-- ===== Сценарий 10. Аналитические запросы ====================================
-- 10.1 «Слабые» темы всех учеников (представление)
SELECT full_name, topic, mastery_percent FROM v_weak_topics ORDER BY full_name, topic;

-- 10.2 Рекомендации ученику 4: нерешённые задачи по его слабым темам
SELECT t.title AS topic, k.task_id, k.exam, k.kim_number, k.difficulty, p.mastery_percent
FROM progress p
JOIN topic t       ON t.topic_id = p.topic_id
JOIN task_topic tt ON tt.topic_id = p.topic_id
JOIN task k        ON k.task_id = tt.task_id
WHERE p.student_id = 4 AND p.mastery_percent < 60
  AND NOT EXISTS (SELECT 1 FROM attempt a
                   WHERE a.student_id = p.student_id AND a.task_id = k.task_id AND a.is_correct)
ORDER BY k.difficulty, k.task_id;

-- 10.3 Рейтинг учеников по XP
SELECT RANK() OVER (ORDER BY sp.xp DESC) AS place, u.full_name, sp.xp, sp.streak_days
FROM student_profile sp JOIN app_user u ON u.user_id = sp.user_id
ORDER BY place, u.full_name
LIMIT 5;
