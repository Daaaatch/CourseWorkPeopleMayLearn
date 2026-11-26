SET search_path TO pml;
-- Сценарий 8. Доход платформы
SELECT month, kind, payments, gross, platform_income
FROM v_platform_revenue ORDER BY month, kind::text;
