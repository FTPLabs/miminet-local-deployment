# Локальный запуск Miminet

## Быстрый путь

Нужен Docker Desktop (Windows/macOS) или Docker Engine (Linux), а также включённый Compose v2. Из корня репозитория выполните:

```sh
./scripts/setup.sh
```

Скрипт не использует `sudo`, не зависит от текущего каталога и сам выбирает доступный Docker/Podman. Старый `./start_all_containers.sh` оставлен как совместимый wrapper.

После запуска откройте <http://127.0.0.1/>. В dev-конфигурации доступен локальный вход:

- email: `developer@miminet.local`
- пароль: `password`

Эта учётная запись создаётся только при `LOCAL_AUTH_ENABLED=true` и только при запуске `MODE=dev`. В production локальный вход выключен, поэтому OAuth-настройки приложения не меняются. Перед публикацией dev-окружения смените `LOCAL_AUTH_PASSWORD` в `front/.env`.

## Поддержка платформ

| Платформа | Веб-интерфейс и PostgreSQL/RabbitMQ | Mininet/OVS backend |
| --- | --- | --- |
| Linux с Docker Engine | поддерживается | поддерживается при запуске Docker с нужными привилегиями |
| macOS с Docker Desktop | поддерживается | отключён по умолчанию: Docker Desktop использует Linux VM, а backend требует Linux kernel networking |
| Windows с Docker Desktop | поддерживается | отключён по умолчанию по той же причине |
| WSL2 | поддерживается | отключён автоматически; включайте `MIMINET_WITH_BACKEND=1` только после проверки privileged-контейнера и OVS в вашей конфигурации |

На macOS, Windows и WSL2 команда запускает frontend-only stack. Это позволяет разрабатывать интерфейс, авторизацию и работу с базой без misleading-падения backend. Полную эмуляцию следует запускать на Linux или в отдельной Linux VM/CI.

Чтобы явно изменить поведение:

```sh
MIMINET_WITH_BACKEND=0 ./scripts/setup.sh  # frontend-only
MIMINET_WITH_BACKEND=1 ./scripts/setup.sh  # opt-in backend
```

В Windows PowerShell используйте:

```powershell
.\scripts\setup.ps1
```

## Что изменилось по сравнению со старым запуском

Compose больше не закрепляет контейнеры на подсетях `172.18.0.0/16` и `172.20.0.0/16` и не использует статические IP. Сервисы обращаются друг к другу по DNS-именам Compose (`postgres`, `rabbitmq`, `miminet`). Поэтому запуск не конфликтует с уже существующими Docker-сетями и не требует ручного редактирования IP в `.env`.

Backend запускается отдельно от frontend и использует собственный Compose-файл. Если он не поддерживается текущим ядром, frontend всё равно может быть запущен. Это особенно важно для Docker Desktop и WSL2.

## Диагностика

Проверить итоговую конфигурацию frontend:

```sh
docker compose --project-directory front --env-file front/.env \
  -f front/docker-compose.yml config
```

Посмотреть состояние и логи:

```sh
docker compose --project-directory front --env-file front/.env \
  -f front/docker-compose.yml ps
docker compose --project-directory front --env-file front/.env \
  -f front/docker-compose.yml logs --tail=200 miminet nginx postgres rabbitmq
```

Если backend не запускается на Linux, проверьте привилегии Docker и наличие `/dev/net/tun`, затем выполните:

```sh
scripts/back-test.sh build
scripts/back-test.sh probe
```

Не копируйте `vk_auth.json` или OAuth credentials для локальной разработки: они нужны только если вы проверяете конкретный внешний provider.
