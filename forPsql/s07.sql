SET search_path TO pml;
-- Сценарий 7. Тариф репетитора и лимит учеников
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
