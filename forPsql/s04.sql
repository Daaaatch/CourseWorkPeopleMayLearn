SET search_path TO pml;
-- Сценарий 4. Жизненный цикл занятия
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
