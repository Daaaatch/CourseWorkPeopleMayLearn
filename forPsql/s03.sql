SET search_path TO pml;
-- Сценарий 3. Покупка Premium-подписки
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
