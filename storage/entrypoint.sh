#!/bin/sh
# Запуск rest-server с аутентификацией по паролю из Docker secret
set -eu

PASS_FILE="${STORAGE_PASSWORD_FILE:-/run/secrets/storage_password}"
HTPASSWD=/etc/rest-server/.htpasswd

if [ ! -s "$PASS_FILE" ]; then
    echo "Ошибка: не найден секрет с паролем хранилища ($PASS_FILE)" >&2
    exit 1
fi

mkdir -p /etc/rest-server
PASS=$(tr -d '\r\n' < "$PASS_FILE")
# -B: хеш bcrypt, -c: файл создаётся заново при каждом запуске
htpasswd -B -b -c "$HTPASSWD" "$STORAGE_USER" "$PASS" 2>/dev/null
echo "rest-server: настроен пользователь $STORAGE_USER"

# shellcheck disable=SC2086  # REST_OPTIONS намеренно разбивается на аргументы
exec rest-server --path /data --listen :8000 --htpasswd-file "$HTPASSWD" $REST_OPTIONS