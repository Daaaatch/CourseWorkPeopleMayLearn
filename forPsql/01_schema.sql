-- ============================================================================
-- PeopleMayLearn. Файл 1 из 4: схема базы данных (типы, таблицы, индексы)
-- СУБД: PostgreSQL 16. Скрипт можно запускать повторно: схема pml пересоздаётся.
-- ============================================================================
DROP SCHEMA IF EXISTS pml CASCADE;
CREATE SCHEMA pml;
SET search_path TO pml;

-- Типы-перечисления
CREATE TYPE user_role AS ENUM ('student', 'tutor', 'admin');
CREATE TYPE exam_type AS ENUM ('oge', 'ege', 'school');
CREATE TYPE answer_type AS ENUM ('number', 'text');
CREATE TYPE access_level AS ENUM ('free', 'premium');
CREATE TYPE material_kind AS ENUM ('theory', 'cheat_sheet', 'video');
CREATE TYPE topic_status AS ENUM ('not_started', 'in_progress', 'mastered');
CREATE TYPE lesson_status AS ENUM ('planned', 'in_progress', 'completed', 'calculated', 'paid', 'cancelled');
CREATE TYPE attendance_type AS ENUM ('pending', 'attended', 'missed');
CREATE TYPE homework_status AS ENUM ('assigned', 'done');
CREATE TYPE audience_type AS ENUM ('student', 'tutor');
CREATE TYPE subscription_status AS ENUM ('pending', 'active', 'expired', 'cancelled');
CREATE TYPE payment_kind AS ENUM ('subscription', 'package', 'lesson');
CREATE TYPE payment_status AS ENUM ('pending', 'paid', 'failed', 'refunded');
CREATE TYPE request_status AS ENUM ('new', 'in_work', 'accepted', 'rejected');

-- Таблицы

-- Пользователь
CREATE TABLE app_user (
    user_id           integer       GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    email             varchar(120)  NOT NULL CONSTRAINT ck_user_email CHECK (position('@' in email) > 1),
    password_hash     varchar(100)  NOT NULL,
    full_name         varchar(100)  NOT NULL,
    phone             varchar(20),
    role              user_role     NOT NULL,
    created_at        timestamptz   NOT NULL DEFAULT now(),
    is_active         boolean       NOT NULL DEFAULT true
);

-- Профиль репетитора
CREATE TABLE tutor_profile (
    user_id           integer       PRIMARY KEY REFERENCES app_user(user_id) ON DELETE CASCADE,
    headline          varchar(150)  NOT NULL,
    about             text,
    hourly_price      numeric(8,2)  NOT NULL CHECK (hourly_price > 0),
    is_listed         boolean       NOT NULL DEFAULT false
);

-- Профиль ученика
CREATE TABLE student_profile (
    user_id           integer       PRIMARY KEY REFERENCES app_user(user_id) ON DELETE CASCADE,
    grade             smallint      CHECK (grade BETWEEN 1 AND 11),
    exam              exam_type     NOT NULL DEFAULT 'school',
    target_score      smallint      CHECK (target_score BETWEEN 0 AND 100),
    xp                integer       NOT NULL DEFAULT 0 CHECK (xp >= 0),
    streak_days       integer       NOT NULL DEFAULT 0 CHECK (streak_days >= 0),
    last_active_date  date
);

-- Связь «репетитор — ученик»
CREATE TABLE tutor_student (
    tutor_id          integer       NOT NULL REFERENCES tutor_profile(user_id),
    student_id        integer       NOT NULL REFERENCES student_profile(user_id),
    started_on        date          NOT NULL DEFAULT current_date,
    lesson_price      numeric(8,2)  NOT NULL CHECK (lesson_price >= 0),
    is_active         boolean       NOT NULL DEFAULT true,
    CONSTRAINT pk_tutor_student PRIMARY KEY (tutor_id, student_id)
);

-- Предмет
CREATE TABLE subject (
    subject_id        integer       GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    title             varchar(60)   NOT NULL UNIQUE
);

-- Тема
CREATE TABLE topic (
    topic_id          integer       GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    subject_id        integer       NOT NULL REFERENCES subject(subject_id),
    parent_topic_id   integer       REFERENCES topic(topic_id),
    title             varchar(150)  NOT NULL,
    sort_order        smallint      NOT NULL DEFAULT 1,
    CONSTRAINT ck_topic_parent CHECK (parent_topic_id <> topic_id)
);

-- Задача
CREATE TABLE task (
    task_id           integer       GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    subject_id        integer       NOT NULL REFERENCES subject(subject_id),
    author_id         integer       REFERENCES app_user(user_id),
    exam              exam_type     NOT NULL,
    kim_number        smallint      CHECK (kim_number > 0),
    difficulty        smallint      NOT NULL DEFAULT 1 CHECK (difficulty BETWEEN 1 AND 5),
    statement         text          NOT NULL,
    answer_type       answer_type   NOT NULL DEFAULT 'number',
    correct_answer    varchar(100)  NOT NULL,
    solution          text,
    access            access_level  NOT NULL DEFAULT 'free',
    is_published      boolean       NOT NULL DEFAULT true,
    created_at        timestamptz   NOT NULL DEFAULT now(),
    CONSTRAINT ck_task_kim CHECK (exam = 'school' OR kim_number IS NOT NULL)
);

-- Связь «задача — тема»
CREATE TABLE task_topic (
    task_id           integer       NOT NULL REFERENCES task(task_id) ON DELETE CASCADE,
    topic_id          integer       NOT NULL REFERENCES topic(topic_id),
    CONSTRAINT pk_task_topic PRIMARY KEY (task_id, topic_id)
);

-- Методический материал
CREATE TABLE material (
    material_id       integer       GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    topic_id          integer       NOT NULL REFERENCES topic(topic_id),
    author_id         integer       REFERENCES app_user(user_id),
    title             varchar(150)  NOT NULL,
    kind              material_kind NOT NULL DEFAULT 'theory',
    file_url          varchar(300)  NOT NULL,
    access            access_level  NOT NULL DEFAULT 'free',
    created_at        timestamptz   NOT NULL DEFAULT now()
);

-- Прогресс ученика по теме
CREATE TABLE progress (
    student_id        integer       NOT NULL REFERENCES student_profile(user_id),
    topic_id          integer       NOT NULL REFERENCES topic(topic_id),
    status            topic_status  NOT NULL DEFAULT 'not_started',
    mastery_percent   numeric(5,2)  NOT NULL DEFAULT 0 CHECK (mastery_percent BETWEEN 0 AND 100),
    updated_at        timestamptz   NOT NULL DEFAULT now(),
    CONSTRAINT pk_progress PRIMARY KEY (student_id, topic_id)
);

-- Абонемент
CREATE TABLE lesson_package (
    package_id        integer       GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    tutor_id          integer       NOT NULL,
    student_id        integer       NOT NULL,
    lessons_total     smallint      NOT NULL CHECK (lessons_total > 0),
    lessons_left      smallint      NOT NULL,
    price             numeric(10,2) NOT NULL CHECK (price > 0),
    valid_until       date          NOT NULL,
    created_at        timestamptz   NOT NULL DEFAULT now(),
    CONSTRAINT ck_package_left CHECK (lessons_left BETWEEN 0 AND lessons_total),
    CONSTRAINT fk_package_pair FOREIGN KEY (tutor_id, student_id) REFERENCES tutor_student(tutor_id, student_id)
);

-- Занятие
CREATE TABLE lesson (
    lesson_id         integer       GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    tutor_id          integer       NOT NULL,
    student_id        integer       NOT NULL,
    starts_at         timestamptz   NOT NULL,
    duration_min      smallint      NOT NULL DEFAULT 60 CHECK (duration_min BETWEEN 15 AND 240),
    status            lesson_status NOT NULL DEFAULT 'planned',
    attendance        attendance_type NOT NULL DEFAULT 'pending',
    price             numeric(8,2)  NOT NULL CHECK (price >= 0),
    package_id        integer       REFERENCES lesson_package(package_id),
    note              text,
    CONSTRAINT fk_lesson_pair FOREIGN KEY (tutor_id, student_id) REFERENCES tutor_student(tutor_id, student_id),
    CONSTRAINT uq_lesson_slot UNIQUE (tutor_id, starts_at)
);

-- Связь «занятие — тема»
CREATE TABLE lesson_topic (
    lesson_id         integer       NOT NULL REFERENCES lesson(lesson_id) ON DELETE CASCADE,
    topic_id          integer       NOT NULL REFERENCES topic(topic_id),
    CONSTRAINT pk_lesson_topic PRIMARY KEY (lesson_id, topic_id)
);

-- Домашнее задание
CREATE TABLE homework (
    homework_id       integer       GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    lesson_id         integer       REFERENCES lesson(lesson_id),
    student_id        integer       NOT NULL REFERENCES student_profile(user_id),
    assigned_by       integer       REFERENCES tutor_profile(user_id),
    title             varchar(150)  NOT NULL,
    assigned_at       timestamptz   NOT NULL DEFAULT now(),
    due_at            timestamptz,
    status            homework_status NOT NULL DEFAULT 'assigned',
    CONSTRAINT uq_homework_student UNIQUE (homework_id, student_id),
    CONSTRAINT ck_homework_due CHECK (due_at IS NULL OR due_at > assigned_at)
);

-- Связь «задание — задача»
CREATE TABLE homework_task (
    homework_id       integer       NOT NULL REFERENCES homework(homework_id) ON DELETE CASCADE,
    task_id           integer       NOT NULL REFERENCES task(task_id),
    sort_order        smallint      NOT NULL DEFAULT 1,
    CONSTRAINT pk_homework_task PRIMARY KEY (homework_id, task_id)
);

-- Попытка (ответ ученика)
CREATE TABLE attempt (
    attempt_id        integer       GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    student_id        integer       NOT NULL REFERENCES student_profile(user_id),
    task_id           integer       NOT NULL REFERENCES task(task_id),
    homework_id       integer,
    answer            varchar(100)  NOT NULL,
    is_correct        boolean       NOT NULL DEFAULT false,
    submitted_at      timestamptz   NOT NULL DEFAULT now(),
    time_spent_sec    integer       CHECK (time_spent_sec >= 0),
    CONSTRAINT fk_attempt_hw_task FOREIGN KEY (homework_id, task_id) REFERENCES homework_task(homework_id, task_id),
    CONSTRAINT fk_attempt_hw_student FOREIGN KEY (homework_id, student_id) REFERENCES homework(homework_id, student_id)
);

-- Тариф
CREATE TABLE subscription_plan (
    plan_id           integer       GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    code              varchar(30)   NOT NULL UNIQUE,
    title             varchar(80)   NOT NULL,
    audience          audience_type NOT NULL,
    price_month       numeric(8,2)  NOT NULL CHECK (price_month >= 0),
    max_students      integer       CHECK (max_students > 0),
    description       text
);

-- Подписка
CREATE TABLE subscription (
    subscription_id   integer       GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_id           integer       NOT NULL REFERENCES app_user(user_id),
    plan_id           integer       NOT NULL REFERENCES subscription_plan(plan_id),
    started_at        date          NOT NULL,
    ends_at           date          NOT NULL,
    status            subscription_status NOT NULL DEFAULT 'pending',
    CONSTRAINT ck_subscription_period CHECK (ends_at > started_at)
);

-- Платёж
CREATE TABLE payment (
    payment_id        integer       GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    payer_id          integer       NOT NULL REFERENCES app_user(user_id),
    kind              payment_kind  NOT NULL,
    amount            numeric(10,2) NOT NULL CHECK (amount > 0),
    platform_fee      numeric(10,2) NOT NULL DEFAULT 0,
    status            payment_status NOT NULL DEFAULT 'pending',
    created_at        timestamptz   NOT NULL DEFAULT now(),
    paid_at           timestamptz,
    subscription_id   integer       REFERENCES subscription(subscription_id),
    package_id        integer       REFERENCES lesson_package(package_id),
    lesson_id         integer       REFERENCES lesson(lesson_id),
    CONSTRAINT ck_payment_fee CHECK (platform_fee BETWEEN 0 AND amount),
    CONSTRAINT ck_payment_paid CHECK (status <> 'paid' OR paid_at IS NOT NULL),
    CONSTRAINT ck_payment_target CHECK ((kind = 'subscription' AND subscription_id IS NOT NULL AND package_id IS NULL AND lesson_id IS NULL) OR (kind = 'package' AND package_id IS NOT NULL AND subscription_id IS NULL AND lesson_id IS NULL) OR (kind = 'lesson' AND lesson_id IS NOT NULL AND subscription_id IS NULL AND package_id IS NULL))
);

-- Заявка на консультацию
CREATE TABLE lead_request (
    request_id        integer       GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    tutor_id          integer       REFERENCES tutor_profile(user_id),
    subject_id        integer       NOT NULL REFERENCES subject(subject_id),
    name              varchar(100)  NOT NULL,
    contact           varchar(100)  NOT NULL,
    message           text,
    status            request_status NOT NULL DEFAULT 'new',
    created_at        timestamptz   NOT NULL DEFAULT now()
);

-- Индексы (первичные ключи и UNIQUE индексируются автоматически)
CREATE UNIQUE INDEX uq_user_email ON app_user (lower(email));
CREATE INDEX idx_topic_parent ON topic (parent_topic_id);
CREATE INDEX idx_task_catalog ON task (exam, kim_number) WHERE is_published;
CREATE INDEX idx_task_topic_topic ON task_topic (topic_id);
CREATE INDEX idx_material_topic ON material (topic_id);
CREATE INDEX idx_attempt_student_time ON attempt (student_id, submitted_at);
CREATE INDEX idx_attempt_task ON attempt (task_id);
CREATE INDEX idx_lesson_tutor_time ON lesson (tutor_id, starts_at);
CREATE INDEX idx_lesson_student_time ON lesson (student_id, starts_at);
CREATE INDEX idx_homework_student ON homework (student_id);
CREATE UNIQUE INDEX uq_subscription_active ON subscription (user_id) WHERE status = 'active';
CREATE INDEX idx_payment_payer ON payment (payer_id, created_at);
CREATE INDEX idx_payment_paid ON payment (paid_at) WHERE status = 'paid';
CREATE INDEX idx_request_new ON lead_request (created_at) WHERE status = 'new';
