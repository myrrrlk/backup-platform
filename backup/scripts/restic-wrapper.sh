#!/bin/sh
# Обёртка для ручного запуска restic администратором:
# подключает адрес и пароль репозитория, затем запускает настоящий restic.
# Пример: docker compose exec backup restic snapshots
# shellcheck source=SCRIPTDIR/common.sh
. /opt/backup/common.sh
exec /usr/bin/restic "$@"