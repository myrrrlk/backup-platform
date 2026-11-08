-- Демонстрационная база данных условной организации
CREATE TABLE employees (
    id         SERIAL PRIMARY KEY,
    full_name  TEXT        NOT NULL,
    position   TEXT        NOT NULL,
    hired_at   DATE        NOT NULL
);

CREATE TABLE documents (
    id          SERIAL PRIMARY KEY,
    title       TEXT        NOT NULL,
    content     TEXT        NOT NULL,
    author_id   INTEGER     NOT NULL REFERENCES employees (id),
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE orders (
    id          SERIAL PRIMARY KEY,
    customer    TEXT           NOT NULL,
    amount      NUMERIC(12, 2) NOT NULL,
    status      TEXT           NOT NULL,
    created_at  TIMESTAMPTZ    NOT NULL DEFAULT now()
);

INSERT INTO employees (full_name, position, hired_at)
SELECT 'Сотрудник ' || g,
       (ARRAY['Инженер', 'Аналитик', 'Бухгалтер', 'Менеджер'])[1 + g % 4],
       DATE '2018-01-01' + (g * 7)
FROM generate_series(1, 200) AS g;

INSERT INTO documents (title, content, author_id, created_at)
SELECT 'Документ № ' || g,
       repeat('Текст служебного документа. ', 20 + g % 30),
       1 + g % 200,
       now() - (g || ' hours')::interval
FROM generate_series(1, 5000) AS g;

INSERT INTO orders (customer, amount, status, created_at)
SELECT 'Клиент ' || (1 + g % 750),
       round((random() * 100000)::numeric, 2),
       (ARRAY['новый', 'оплачен', 'отгружен', 'закрыт'])[1 + g % 4],
       now() - (g || ' minutes')::interval
FROM generate_series(1, 10000) AS g;