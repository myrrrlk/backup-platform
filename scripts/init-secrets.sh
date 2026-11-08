#!/bin/sh
# Генерация паролей в каталоге secrets/ (существующие файлы не перезаписываются).
# ВНИМАНИЕ: без restic_password восстановить резервные копии невозможно,
# храните его копию отдельно от платформы (например, в менеджере паролей).
set -eu
cd "$(dirname "$0")/.."
mkdir -p secrets

for name in db_password storage_password restic_password; do
    file="secrets/$name.txt"
    if [ ! -s "$file" ]; then
        # Шестнадцатеричный пароль: 32 символа, безопасен для использования в URL
        openssl rand -hex 16 | tr -d '\r\n' > "$file"
        echo "Создан $file"
    else
        echo "Уже существует $file"
    fi
done