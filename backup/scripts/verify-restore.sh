#!/bin/sh
# Тестовое восстановление: снимок разворачивается во временную БД,
# количество строк сравнивается с данными, зафиксированными в момент копирования.
# Рабочая база данных при этом не изменяется.
# Использование: verify-restore.sh [ID_снимка|latest]
set -eu
# shellcheck source=SCRIPTDIR/common.sh
. /opt/backup/common.sh

SNAPSHOT="${1:-latest}"
TMP=/tmp/verify
VERIFY_DB="${PGDATABASE}_verify"

cleanup() {
    rm -rf "$TMP"
    dropdb --if-exists "$VERIFY_DB" > /dev/null 2>&1 || true
}
trap cleanup EXIT

log "Проверка восстановления снимка $SNAPSHOT"
rm -rf "$TMP"
restic restore "$SNAPSHOT" --host "$BACKUP_HOST_TAG" --target "$TMP" --include "$WORK_DIR/db" > /dev/null

dropdb --if-exists "$VERIFY_DB"
createdb "$VERIFY_DB"
pg_restore --no-owner -d "$VERIFY_DB" "$TMP$WORK_DIR/db/$PGDATABASE.dump"

row_counts "$VERIFY_DB" > "$TMP/actual.txt"
EXPECTED="$TMP$WORK_DIR/db/rowcounts.txt"

echo "Таблица | ожидалось | восстановлено"
awk -F'|' 'NR == FNR { want[$1] = $2; next } { printf "%s | %s | %s\n", $1, want[$1], $2 }' \
    "$EXPECTED" "$TMP/actual.txt"

if diff -q "$EXPECTED" "$TMP/actual.txt" > /dev/null; then
    log "РЕЗУЛЬТАТ: восстановление проверено, данные совпадают"
else
    log "РЕЗУЛЬТАТ: обнаружено расхождение данных"
    exit 1
fi