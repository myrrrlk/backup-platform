#!/bin/sh
# Точка входа контейнера backup: ожидание сервисов, инициализация репозитория, запуск cron
set -eu

# 1. Сохраняем несекретные переменные окружения для заданий cron
env | grep -E '^(PG|STORAGE_HOST|STORAGE_USER|REPO_NAME|SOURCE_DIR|KEEP_|BACKUP_|TZ)' |
    sed "s/^\([^=]*\)=\(.*\)$/export \1='\2'/" > /opt/backup/runtime.env

# shellcheck source=SCRIPTDIR/common.sh
. /opt/backup/common.sh
log "Агент резервного копирования запускается"

# 2. Ожидание готовности СУБД (в Docker Swarm depends_on не учитывается)
i=0
until pg_isready -q; do
    i=$((i + 1))
    if [ "$i" -ge 60 ]; then log "СУБД $PGHOST недоступна"; exit 1; fi
    sleep 2
done
log "СУБД $PGHOST:$PGPORT доступна"

# 3. Ожидание хранилища и инициализация репозитория при первом запуске
i=0
until restic cat config > /dev/null 2>&1; do
    if restic init > /dev/null 2>&1; then
        log "Создан новый зашифрованный репозиторий restic"
        break
    fi
    i=$((i + 1))
    if [ "$i" -ge 30 ]; then log "Хранилище ${STORAGE_HOST:-storage} недоступно"; exit 1; fi
    sleep 2
done
log "Репозиторий доступен"

# 4. Расписание cron; вывод заданий направляется в журнал контейнера (docker logs)
echo "$BACKUP_SCHEDULE /opt/backup/backup.sh --cron > /proc/1/fd/1 2>&1" > /etc/crontabs/root
log "Расписание резервного копирования: $BACKUP_SCHEDULE"

# 5. Первое копирование сразу после запуска (можно отключить BACKUP_ON_START=false)
if [ "$BACKUP_ON_START" = "true" ]; then
    /opt/backup/backup.sh || log "Первое копирование завершилось с ошибкой"
fi

# 6. crond становится основным процессом (PID 1) контейнера
exec crond -f -l 8