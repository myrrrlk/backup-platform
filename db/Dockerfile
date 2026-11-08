# Источник данных: СУБД PostgreSQL с демонстрационной базой company
FROM postgres:17-alpine

# Скрипты из этого каталога выполняются один раз при первом запуске (пустой том)
COPY init/ /docker-entrypoint-initdb.d/

ENV TZ=Europe/Moscow
EXPOSE 5432