SET search_path TO pml;
-- Сценарий 10. Аналитические запросы
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
