SET search_path TO pml;
-- Сценарий 9. Контроль целостности
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
