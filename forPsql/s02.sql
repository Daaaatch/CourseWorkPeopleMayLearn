SET search_path TO pml;
-- Сценарий 2. Каталог задач и Premium
SELECT u.full_name, count(*) AS available_tasks
FROM app_user u
JOIN task t ON t.is_published AND (t.access = 'free' OR has_active_premium(u.user_id, DATE '2026-11-26'))
WHERE u.user_id IN (10, 11)
GROUP BY u.full_name
ORDER BY u.full_name;
