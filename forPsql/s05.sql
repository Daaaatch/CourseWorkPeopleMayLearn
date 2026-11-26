SET search_path TO pml;
-- Сценарий 5. Сквозной сценарий: занятие - расчёт - оплата
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
