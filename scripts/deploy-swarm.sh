#!/bin/sh
# Развёртывание платформы в кластере Docker Swarm (однонодовый кластер на локальном компьютере)
set -eu
cd "$(dirname "$0")/.."

REGISTRY=localhost:5000
STACK=backup

sh scripts/init-secrets.sh

# 1. Инициализация кластера, если узел ещё не входит в Swarm
if [ "$(docker info --format '{{.Swarm.LocalNodeState}}')" != "active" ]; then
    docker swarm init --advertise-addr 127.0.0.1
fi

# 2. Локальный реестр образов (узлы кластера загружают образы из реестра)
if ! docker ps --format '{{.Names}}' | grep -q '^registry$'; then
    docker run -d -p 5000:5000 --restart=always --name registry registry:2
fi

# 3. Сборка и публикация образов в реестре
for service in db storage backup dashboard; do
    docker build -t "$REGISTRY/backup-platform-$service:latest" "./$service"
    docker push "$REGISTRY/backup-platform-$service:latest"
done

# 4. Развёртывание стека
docker stack deploy -c docker-stack.yaml "$STACK"
docker stack services "$STACK"