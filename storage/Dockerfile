# Хранилище резервных копий: официальный REST-сервер restic
FROM restic/rest-server:0.14.0

COPY entrypoint.sh /usr/local/bin/storage-entrypoint.sh
# Удаляем символы CR (если файл сохранён в Windows) и делаем скрипт исполняемым
RUN sed -i 's/\r$//' /usr/local/bin/storage-entrypoint.sh \
    && chmod +x /usr/local/bin/storage-entrypoint.sh

ENV STORAGE_USER=backup \
    REST_OPTIONS=""

VOLUME /data
EXPOSE 8000
ENTRYPOINT ["/usr/local/bin/storage-entrypoint.sh"]