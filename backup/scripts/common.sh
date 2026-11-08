#!/bin/sh
# shellcheck disable=SC2034  # переменные используются в подключающих скриптах
# Общие переменные и функции агента резервного копирования.
# Подключается командой ". /opt/backup/common.sh" из остальных скриптов.

# Переменные окружения контейнера сохраняются при старте, чтобы они были доступны заданиям cron
if [ -f /opt/backup/runtime.env ]; then
    # shellcheck source=/dev/null
    . /opt/backup/runtime.env
fi

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

# Чтение секрета из файла без символов перевода строки (CR/LF)
read_secret() {
    tr -d '\r\n' < "$1"
}

# Подключение к PostgreSQL
export PGHOST="${PGHOST:-db}"
export PGPORT="${PGPORT:-5432}"
export PGUSER="${PGUSER:-company_admin}"
export PGDATABASE="${PGDATABASE:-company}"
PGPASSWORD="$(read_secret "${DB_PASSWORD_FILE:-/run/secrets/db_password}")"
export PGPASSWORD

# Подключение к репозиторию restic на rest-server
STORAGE_USER="${STORAGE_USER:-backup}"
STORAGE_PASSWORD="$(read_secret "${STORAGE_PASSWORD_FILE:-/run/secrets/storage_password}")"
RESTIC_REPOSITORY="rest:http://${STORAGE_USER}:${STORAGE_PASSWORD}@${STORAGE_HOST:-storage}:8000/${REPO_NAME:-company}/"
RESTIC_PASSWORD="$(read_secret "${RESTIC_PASSWORD_FILE:-/run/secrets/restic_password}")"
export RESTIC_REPOSITORY RESTIC_PASSWORD

BACKUP_HOST_TAG="${BACKUP_HOST_TAG:-backup-agent}"
STATUS_DIR="${STATUS_DIR:-/status}"
WORK_DIR=/backup-work

# Количество строк во всех таблицах схемы public (используется для проверки восстановления)
row_counts() {
    db="$1"
    psql -d "$db" -At -c "SELECT table_name FROM information_schema.tables
                          WHERE table_schema = 'public' AND table_type = 'BASE TABLE'
                          ORDER BY table_name" |
    while read -r t; do
        printf '%s|%s\n' "$t" "$(psql -d "$db" -At -c "SELECT count(*) FROM \"$t\"")"
    done
}