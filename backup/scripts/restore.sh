#!/bin/sh
# Восстановление данных из снимка restic
# Использование: restore.sh [ID_снимка|latest]
#   - база данных восстанавливается в рабочую БД (объекты пересоздаются);
#   - файлы извлекаются в каталог /restore/<дата>/ для ручной проверки и переноса.
set -eu
# shellcheck source=SCRIPTDIR/common.sh
. /opt/backup/common.sh

SNAPSHOT="${1:-latest}"
TARGET="/restore/$(date '+%Y%m%d-%H%M%S')"

log "Восстановление из снимка $SNAPSHOT в $TARGET"
restic restore "$SNAPSHOT" --host "$BACKUP_HOST_TAG" --target "$TARGET"

DUMP="$TARGET$WORK_DIR/db/$PGDATABASE.dump"
[ -f "$DUMP" ] || { log "В снимке нет дампа $PGDATABASE.dump"; exit 1; }

log "Восстановление базы данных $PGDATABASE"
pg_restore --clean --if-exists --no-owner -d "$PGDATABASE" "$DUMP"

log "Количество строк после восстановления:"
row_counts "$PGDATABASE"
log "Файлы из снимка доступны в каталоге $TARGET$SOURCE_DIR"
log "Восстановление завершено"