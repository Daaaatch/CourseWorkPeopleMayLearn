SET search_path TO pml;
-- Сценарий 6. Баланс учеников
SELECT b.tutor_id, b.student_id, u.full_name, b.paid_total, b.lessons_cost, b.balance, b.package_left
FROM v_student_balance b JOIN app_user u ON u.user_id = b.student_id
ORDER BY b.tutor_id, b.student_id;
