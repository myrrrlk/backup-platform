# Агент резервного копирования: restic + клиентские утилиты PostgreSQL + cron
# Базовый образ postgres:17-alpine выбран, чтобы версия pg_dump совпадала с версией СУБД
FROM postgres:17-alpine

RUN apk add --no-cache restic jq tzdata

COPY scripts/ /opt/backup/
RUN sed -i 's/\r$//' /opt/backup/*.sh \
    && chmod +x /opt/backup/*.sh \
    && for s in backup restore verify-restore; do ln -s "/opt/backup/$s.sh" "/usr/local/bin/$s.sh"; done \
    && ln -s /opt/backup/restic-wrapper.sh /usr/local/bin/restic \
    && mkdir -p /status /restore /backup-work

ENV TZ=Europe/Moscow \
    BACKUP_SCHEDULE="0 2 * * *" \
    BACKUP_ON_START=true \
    SOURCE_DIR=/source/files \
    KEEP_LAST=4 KEEP_DAILY=7 KEEP_WEEKLY=4 KEEP_MONTHLY=6

ENTRYPOINT ["/opt/backup/entrypoint.sh"]