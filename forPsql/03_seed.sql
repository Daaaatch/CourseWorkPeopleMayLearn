-- ============================================================================
-- PeopleMayLearn. Файл 3 из 4: тестовые данные
-- Запускать после 01_schema.sql и 02_logic.sql. Идентификаторы выдаются по
-- порядку строк (1, 2, 3 ...), поэтому на них ссылаются демонстрационные запросы.
-- Прогресс, XP и серии дней рассчитываются триггерами при вставке попыток.
-- ============================================================================
SET search_path TO pml;
TRUNCATE app_user, tutor_profile, student_profile, tutor_student, subject, topic, task, task_topic, material, progress, lesson_package, lesson, lesson_topic, homework, homework_task, attempt, subscription_plan, subscription, payment, lead_request RESTART IDENTITY CASCADE;

INSERT INTO app_user (email, password_hash, full_name, phone, role, created_at) VALUES
    ('admin@peoplemaylearn.test', '$2b$12$xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx', 'Администратор платформы', NULL, 'admin', '2026-09-01 10:00+03'),
    ('tutor1@peoplemaylearn.test', '$2b$12$xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx', 'Конюков Антон Павлович', '+7 900 000-00-01', 'tutor', '2026-09-01 10:05+03'),
    ('tutor2@peoplemaylearn.test', '$2b$12$xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx', 'Смирнова Елена Игоревна', '+7 900 000-00-02', 'tutor', '2026-09-02 11:00+03'),
    ('ivanov@peoplemaylearn.test', '$2b$12$xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx', 'Иванов Пётр', NULL, 'student', '2026-09-10 12:00+03'),
    ('makarova@peoplemaylearn.test', '$2b$12$xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx', 'Макарова Анна', NULL, 'student', '2026-09-15 12:00+03'),
    ('orlov@peoplemaylearn.test', '$2b$12$xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx', 'Орлов Дмитрий', NULL, 'student', '2026-10-01 12:00+03'),
    ('belova@peoplemaylearn.test', '$2b$12$xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx', 'Белова София', NULL, 'student', '2026-09-20 12:00+03'),
    ('gromov@peoplemaylearn.test', '$2b$12$xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx', 'Громов Никита', NULL, 'student', '2026-10-05 12:00+03'),
    ('zaytseva@peoplemaylearn.test', '$2b$12$xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx', 'Зайцева Ольга', NULL, 'student', '2026-10-12 12:00+03'),
    ('volkov@peoplemaylearn.test', '$2b$12$xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx', 'Волков Артём', NULL, 'student', '2026-11-20 12:00+03'),
    ('krylova@peoplemaylearn.test', '$2b$12$xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx', 'Крылова Мария', NULL, 'student', '2026-11-10 12:00+03');

INSERT INTO tutor_profile (user_id, headline, about, hourly_price, is_listed) VALUES
    (2, 'Математика и информатика: ОГЭ, ЕГЭ, 5–11 класс', 'Индивидуальные занятия, учебный план по результатам диагностики.', 1500, true),
    (3, 'Математика: подготовка к ОГЭ и ЕГЭ', 'Работаю с 9–11 классами, упор на разбор типовых ошибок.', 1000, true);

INSERT INTO student_profile (user_id, grade, exam, target_score) VALUES
    (4, 11, 'ege', 80),
    (5, 9, 'oge', NULL),
    (6, 6, 'school', NULL),
    (7, 11, 'ege', 70),
    (8, 10, 'school', NULL),
    (9, 9, 'oge', NULL),
    (10, 11, 'ege', 60),
    (11, 10, 'ege', 85);

INSERT INTO subject (title) VALUES
    ('Математика'),
    ('Информатика');

INSERT INTO topic (subject_id, parent_topic_id, title, sort_order) VALUES
    (1, NULL, 'Арифметика и алгебра', 1),
    (1, 1, 'Обыкновенные и десятичные дроби', 1),
    (1, 1, 'Проценты', 2),
    (1, 1, 'Уравнения и неравенства', 3),
    (1, NULL, 'Геометрия', 2),
    (1, 5, 'Планиметрия: треугольники', 1),
    (1, NULL, 'Теория вероятностей', 3),
    (2, NULL, 'Системы счисления', 1),
    (2, NULL, 'Логика', 2),
    (2, 9, 'Таблицы истинности', 1),
    (2, NULL, 'Программирование', 3),
    (2, 11, 'Циклы и массивы', 1);

INSERT INTO tutor_student (tutor_id, student_id, started_on, lesson_price) VALUES
    (2, 4, '2026-09-10', 1500),
    (2, 5, '2026-09-15', 1200),
    (2, 6, '2026-10-01', 1000),
    (3, 7, '2026-09-20', 1000),
    (3, 8, '2026-10-05', 900),
    (3, 9, '2026-10-12', 800);

INSERT INTO task (subject_id, author_id, exam, kim_number, difficulty, statement, answer_type, correct_answer, solution, access) VALUES
    (1, 2, 'ege', 1, 1, 'В треугольнике ABC угол C равен 90°, AC = 8, BC = 6. Найдите AB.', 'number', '10', 'По теореме Пифагора AB = √(8² + 6²) = 10.', 'free'),
    (1, 2, 'ege', 4, 2, 'Дважды бросают игральную кость. Найдите вероятность того, что в сумме выпало 8 очков. Результат округлите до сотых.', 'number', '0.14', 'Благоприятных исходов 5 из 36: 5/36 ≈ 0,14.', 'premium'),
    (1, 2, 'ege', 6, 1, 'Найдите корень уравнения 2^(x−1) = 16.', 'number', '5', '2^(x−1) = 2⁴, откуда x − 1 = 4 и x = 5.', 'free'),
    (1, 2, 'school', NULL, 1, 'Найдите 15% от числа 240.', 'number', '36', '240 · 0,15 = 36.', 'free'),
    (1, 2, 'school', NULL, 2, 'Вычислите 3/4 + 1/6. Ответ запишите десятичной дробью, округлив до сотых.', 'number', '0.92', '3/4 + 1/6 = 11/12 ≈ 0,92.', 'free'),
    (1, 2, 'school', NULL, 1, 'Сократите дробь 18/24. В ответе укажите числитель полученной дроби.', 'number', '3', '18/24 = 3/4.', 'free'),
    (1, 2, 'school', NULL, 2, 'Цена товара 800 ₽ выросла на 25%. Какой стала цена (в рублях)?', 'number', '1000', '800 · 1,25 = 1000.', 'free'),
    (1, NULL, 'oge', 9, 2, 'Решите уравнение x² − 5x + 6 = 0. Если корней несколько, в ответе запишите меньший из них.', 'number', '2', 'Корни 2 и 3, меньший — 2.', 'free'),
    (2, 2, 'ege', 14, 2, 'Запишите число 45 в двоичной системе счисления.', 'text', '101101', '45 = 32 + 8 + 4 + 1 = 101101₂.', 'free'),
    (2, 2, 'ege', 2, 3, 'Сколько существует наборов значений x, y, z, при которых выражение (x ∧ y) ∨ ¬z истинно?', 'number', '5', 'При z = 0 истинно для любых x, y (4 набора); при z = 1 — только при x = y = 1 (1 набор). Всего 5.', 'premium'),
    (2, NULL, 'school', NULL, 2, 'Чему равно значение s после выполнения фрагмента: s = 0; for i in range(1, 6): s += i ?', 'number', '15', '1 + 2 + 3 + 4 + 5 = 15.', 'free'),
    (2, 2, 'ege', 14, 2, 'Сколько единиц содержится в двоичной записи десятичного числа 37?', 'number', '3', '37 = 100101₂, три единицы.', 'free'),
    (2, NULL, 'school', NULL, 1, 'Переведите двоичное число 1101 в десятичную систему счисления.', 'number', '13', '8 + 4 + 1 = 13.', 'free'),
    (1, 2, 'ege', 1, 1, 'Найдите площадь прямоугольного треугольника с катетами 5 и 12.', 'number', '30', 'S = 5 · 12 / 2 = 30.', 'free'),
    (1, 2, 'ege', 6, 2, 'Найдите корень уравнения √(x + 5) = 3.', 'number', '4', 'x + 5 = 9, x = 4.', 'free'),
    (1, 2, 'ege', 4, 2, 'Монету бросают дважды. Найдите вероятность того, что орёл выпадет ровно один раз.', 'number', '0.5', 'Исходов 4, благоприятных 2: 2/4 = 0,5.', 'free'),
    (1, 2, 'ege', 4, 1, 'Игральную кость бросают один раз. Найдите вероятность того, что выпадет чётное число очков.', 'number', '0.5', 'Чётных граней 3 из 6: 0,5.', 'free');

INSERT INTO task_topic (task_id, topic_id) VALUES
    (1, 6),
    (2, 7),
    (3, 4),
    (4, 3),
    (5, 2),
    (6, 2),
    (7, 3),
    (8, 4),
    (9, 8),
    (10, 10),
    (10, 9),
    (11, 12),
    (12, 8),
    (13, 8),
    (14, 6),
    (15, 4),
    (16, 7),
    (17, 7);

INSERT INTO material (topic_id, author_id, title, kind, file_url, access) VALUES
    (3, 2, 'Проценты: три типа задач', 'cheat_sheet', '/files/percent.pdf', 'free'),
    (2, 2, 'Дроби: сокращение и сравнение', 'theory', '/files/fractions.pdf', 'free'),
    (8, 2, 'Системы счисления: быстрый перевод', 'theory', '/files/numsys.pdf', 'free'),
    (7, 2, 'Вероятность: разбор типовых задач ЕГЭ', 'video', '/files/probability.mp4', 'premium');

INSERT INTO lesson_package (tutor_id, student_id, lessons_total, lessons_left, price, valid_until, created_at) VALUES
    (2, 4, 4, 2, 5200, '2027-06-30', '2026-11-01 12:00+03');

INSERT INTO lesson (tutor_id, student_id, starts_at, duration_min, status, attendance, price, package_id, note) VALUES
    (2, 4, '2026-11-03 17:00+03', 60, 'paid', 'attended', 1300, 1, NULL),
    (2, 4, '2026-11-10 17:00+03', 60, 'paid', 'attended', 1300, 1, NULL),
    (2, 4, '2026-11-17 17:00+03', 60, 'completed', 'attended', 1500, NULL, 'Планиметрия, вероятность'),
    (2, 5, '2026-11-05 16:00+03', 60, 'paid', 'attended', 1200, NULL, NULL),
    (2, 5, '2026-11-12 16:00+03', 60, 'calculated', 'attended', 1200, NULL, NULL),
    (2, 5, '2026-11-19 16:00+03', 60, 'completed', 'missed', 1200, NULL, 'Пропуск без предупреждения'),
    (2, 5, '2026-12-03 16:00+03', 60, 'planned', 'pending', 1200, NULL, NULL),
    (2, 6, '2026-11-04 15:00+03', 60, 'paid', 'attended', 1000, NULL, NULL),
    (2, 6, '2026-11-11 15:00+03', 60, 'paid', 'attended', 1000, NULL, NULL),
    (3, 7, '2026-11-06 18:00+03', 60, 'paid', 'attended', 1000, NULL, NULL);

INSERT INTO lesson_topic (lesson_id, topic_id) VALUES
    (1, 4),
    (2, 6),
    (3, 6),
    (3, 7),
    (4, 3),
    (5, 2),
    (8, 2),
    (9, 3),
    (10, 4);

INSERT INTO homework (lesson_id, student_id, assigned_by, title, assigned_at, due_at, status) VALUES
    (3, 4, 2, 'ДЗ: планиметрия и вероятность', '2026-11-17 19:00+03', '2026-11-24 23:59+03', 'done');

INSERT INTO homework_task (homework_id, task_id, sort_order) VALUES
    (1, 1, 1),
    (1, 14, 2),
    (1, 2, 3),
    (1, 16, 4);

INSERT INTO subscription_plan (code, title, audience, price_month, max_students, description) VALUES
    ('student_premium', 'Premium для ученика', 'student', 490, NULL, 'Все задачи и разборы, пробные варианты, персональный план, статистика без ограничений'),
    ('tutor_start', 'Репетитор Start', 'tutor', 390, 10, 'До 10 учеников, расписание, домашние задания, финансовый учёт'),
    ('tutor_pro', 'Репетитор Pro', 'tutor', 790, NULL, 'Без лимита учеников, свои задачи и материалы, приоритет в каталоге');

INSERT INTO subscription (user_id, plan_id, started_at, ends_at, status) VALUES
    (2, 3, '2026-11-01', '2026-12-01', 'active'),
    (11, 1, '2026-11-10', '2026-12-10', 'active');

INSERT INTO payment (payer_id, kind, amount, status, created_at, paid_at, subscription_id, package_id, lesson_id) VALUES
    (4, 'package', 5200, 'paid', '2026-11-01 12:00+03', '2026-11-01 12:05+03', NULL, 1, NULL),
    (5, 'lesson', 1200, 'paid', '2026-11-05 16:45+03', '2026-11-05 16:50+03', NULL, NULL, 4),
    (6, 'lesson', 1000, 'paid', '2026-11-04 15:50+03', '2026-11-04 15:55+03', NULL, NULL, 8),
    (6, 'lesson', 1000, 'paid', '2026-11-11 15:50+03', '2026-11-11 15:55+03', NULL, NULL, 9),
    (7, 'lesson', 1000, 'paid', '2026-11-06 18:50+03', '2026-11-06 18:55+03', NULL, NULL, 10),
    (2, 'subscription', 790, 'paid', '2026-11-01 10:10+03', '2026-11-01 10:11+03', 1, NULL, NULL),
    (11, 'subscription', 490, 'paid', '2026-11-10 12:10+03', '2026-11-10 12:11+03', 2, NULL, NULL);

INSERT INTO attempt (student_id, task_id, homework_id, answer, submitted_at, time_spent_sec) VALUES
    (4, 1, 1, '10', '2026-11-20 18:00+03', 140),
    (4, 14, 1, '30', '2026-11-20 18:05+03', 95),
    (4, 2, 1, '0,14', '2026-11-21 18:00+03', 210),
    (4, 16, 1, '0.25', '2026-11-21 18:07+03', 80),
    (4, 3, NULL, '4', '2026-11-22 18:00+03', 60),
    (4, 15, NULL, '4', '2026-11-22 18:04+03', 75),
    (4, 3, NULL, '5', '2026-11-23 18:00+03', 50),
    (4, 2, NULL, '0.15', '2026-11-23 18:06+03', 120),
    (4, 16, NULL, '0.33', '2026-11-24 18:00+03', 90),
    (4, 1, NULL, '8', '2026-11-24 18:03+03', 40);

INSERT INTO attempt (student_id, task_id, homework_id, answer, submitted_at, time_spent_sec) VALUES
    (6, 4, NULL, '36', '2026-11-23 15:30+03', 45),
    (6, 7, NULL, '1000', '2026-11-23 15:40+03', 70),
    (6, 5, NULL, '0,92', '2026-11-24 15:30+03', 160),
    (6, 6, NULL, '4', '2026-11-24 15:40+03', 55),
    (6, 5, NULL, '0.91', '2026-11-25 15:30+03', 100),
    (6, 4, NULL, '35', '2026-11-25 15:40+03', 35);

INSERT INTO attempt (student_id, task_id, homework_id, answer, submitted_at, time_spent_sec) VALUES
    (11, 9, NULL, '101101', '2026-11-24 20:00+03', 90),
    (11, 12, NULL, '3', '2026-11-24 20:05+03', 60),
    (11, 13, NULL, '13', '2026-11-24 20:08+03', 30),
    (11, 10, NULL, '6', '2026-11-25 20:00+03', 180),
    (11, 10, NULL, '5', '2026-11-25 20:06+03', 150),
    (11, 11, NULL, '15', '2026-11-25 20:10+03', 70),
    (11, 9, NULL, '101101', '2026-11-25 20:15+03', 40),
    (11, 12, NULL, '3', '2026-11-25 20:18+03', 35);

INSERT INTO lead_request (tutor_id, subject_id, name, contact, message, status) VALUES
    (3, 1, 'Мама Анны', '+7 900 111-22-33', 'Нужна подготовка к ОГЭ по математике', 'new'),
    (NULL, 2, 'Сергей', 'sergey@example.test', 'Подготовка к ЕГЭ по информатике, 11 класс', 'in_work'),
    (2, 1, 'Елена', '+7 900 444-55-66', 'Помощь с дробями, 6 класс', 'accepted');
