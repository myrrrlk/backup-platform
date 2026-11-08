#!/bin/sh
# Создание резервной копии: дамп БД и файлы -> снимок restic -> политика хранения -> проверка
# Использование: backup.sh [--cron]
set -eu
# shellcheck source=SCRIPTDIR/common.sh
. /opt/backup/common.sh

# Блокировка от одновременного запуска: задание cron пропускается,
# ручной запуск ожидает завершения текущего копирования
exec 9> /tmp/backup.lock
if [ "${1:-}" = "--cron" ]; then
    flock -n 9 || { log "Предыдущее копирование ещё выполняется, запуск пропущен"; exit 0; }
else
    flock 9
fi

START=$(date +%s)
mkdir -p "$STATUS_DIR"
[ -f "$STATUS_DIR/history.json" ] || echo '[]' > "$STATUS_DIR/history.json"

# Запись статуса для панели мониторинга (status.json и история последних 30 запусков)
write_status() {
    entry=$(jq -n \
        --arg status "$1" --arg message "$2" --arg snapshot "${3:-}" \
        --arg finished "$(date '+%Y-%m-%d %H:%M:%S')" \
        --argjson duration "$(( $(date +%s) - START ))" \
        --argjson added "${4:-0}" --argjson total "${5:-0}" --argjson size "${6:-0}" \
        --arg schedule "$BACKUP_SCHEDULE" \
        '{status: $status, message: $message, snapshot_id: $snapshot, finished_at: $finished,
          duration_sec: $duration, data_added_bytes: $added, snapshots_total: $total,
          repo_size_bytes: $size, schedule: $schedule}')
    echo "$entry" > "$STATUS_DIR/status.json.tmp" && mv "$STATUS_DIR/status.json.tmp" "$STATUS_DIR/status.json"
    jq --argjson e "$entry" '([$e] + .)[:30]' "$STATUS_DIR/history.json" > "$STATUS_DIR/history.json.tmp" \
        && mv "$STATUS_DIR/history.json.tmp" "$STATUS_DIR/history.json"
}

fail() {
    log "ОШИБКА: $1"
    write_status "failed" "$1"
    exit 1
}

log "=== Начало резервного копирования ==="
rm -rf "$WORK_DIR" && mkdir -p "$WORK_DIR/db"

# Быстрая проверка доступности хранилища и пароля (без долгих повторных попыток restic)
wget -q -T 10 -O /dev/null \
    "http://${STORAGE_USER}:${STORAGE_PASSWORD}@${STORAGE_HOST:-storage}:8000/${REPO_NAME:-company}/config" \
    || fail "хранилище копий недоступно"

# Шаг 1. Логический дамп БД (custom-формат без сжатия: restic сжимает и дедуплицирует сам)
log "Шаг 1/4: дамп базы данных $PGDATABASE"
pg_dump -Fc -Z 0 -f "$WORK_DIR/db/$PGDATABASE.dump" || fail "ошибка pg_dump"
row_counts "$PGDATABASE" > "$WORK_DIR/db/rowcounts.txt" || fail "ошибка подсчёта строк"

# Шаг 2. Снимок restic: дамп и каталог с файлами
SOURCES="$WORK_DIR/db"
if [ -d "$SOURCE_DIR" ]; then SOURCES="$SOURCES $SOURCE_DIR"; fi
log "Шаг 2/4: создание снимка ($SOURCES)"
# shellcheck disable=SC2086  # список каталогов намеренно разбивается на аргументы
restic backup $SOURCES --host "$BACKUP_HOST_TAG" --tag auto --json > "$WORK_DIR/backup.json" \
    || fail "ошибка restic backup"
SNAPSHOT=$(jq -r 'select(.message_type == "summary") | .snapshot_id' "$WORK_DIR/backup.json" | cut -c1-8)
ADDED=$(jq -r 'select(.message_type == "summary") | .data_added' "$WORK_DIR/backup.json")
log "Создан снимок $SNAPSHOT, новых данных: $ADDED байт"

# Шаг 3. Политика хранения: удаление устаревших снимков и неиспользуемых данных
log "Шаг 3/4: политика хранения (last=$KEEP_LAST daily=$KEEP_DAILY weekly=$KEEP_WEEKLY monthly=$KEEP_MONTHLY)"
restic forget --host "$BACKUP_HOST_TAG" --tag auto \
    --keep-last "$KEEP_LAST" --keep-daily "$KEEP_DAILY" \
    --keep-weekly "$KEEP_WEEKLY" --keep-monthly "$KEEP_MONTHLY" --prune > /dev/null \
    || fail "ошибка restic forget/prune"

# Шаг 4. Проверка целостности структуры репозитория
log "Шаг 4/4: проверка целостности репозитория"
restic check > /dev/null 2>&1 || fail "проверка целостности не пройдена"

TOTAL=$(restic snapshots --json | jq 'length')
SIZE=$(restic stats --mode raw-data --json | jq '.total_size')
write_status "success" "Копирование выполнено успешно" "$SNAPSHOT" "$ADDED" "$TOTAL" "$SIZE"
rm -rf "$WORK_DIR"
log "=== Копирование завершено за $(( $(date +%s) - START )) с, снимков в репозитории: $TOTAL ==="