SET search_path TO pml;
-- Сценарий 1. Ученик решает задачи: автопроверка, прогресс, XP
-- Волков Артём (user_id = 10) отправляет верный и неверный ответ на задачу 4
INSERT INTO attempt (student_id, task_id, answer) VALUES (10, 4, '36'), (10, 4, '35');

SELECT attempt_id, task_id, answer, is_correct
FROM attempt WHERE student_id = 10 ORDER BY attempt_id;

SELECT topic_id, status, mastery_percent FROM progress WHERE student_id = 10;
SELECT xp, streak_days FROM student_profile WHERE user_id = 10;
