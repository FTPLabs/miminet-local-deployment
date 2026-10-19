#!/usr/bin/env sh
set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
ENGINE=${MIMINET_ENGINE:-}
WITH_BACKEND=${MIMINET_WITH_BACKEND:-auto}

if [ -z "$ENGINE" ]; then
  if command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
    ENGINE=docker
  elif command -v podman >/dev/null 2>&1 && podman info >/dev/null 2>&1; then
    ENGINE=podman
  else
    echo "ERROR: Docker/Podman is not installed or its daemon is not running." >&2
    echo "Install Docker Desktop (Windows/macOS) or Docker Engine (Linux), then retry." >&2
    exit 1
  fi
fi

case "$ENGINE" in
  docker|podman) ;;
  *) echo "ERROR: unsupported MIMINET_ENGINE=$ENGINE (use docker or podman)." >&2; exit 1 ;;
esac

if [ "$WITH_BACKEND" = auto ]; then
  case "$(uname -s 2>/dev/null || echo unknown)" in
    Linux)
      case "$(uname -r 2>/dev/null || echo '')" in
        *microsoft*|*Microsoft*) WITH_BACKEND=0 ;; # WSL: opt in after checking Docker/OVS support
        *) WITH_BACKEND=1 ;;
      esac
      ;;
    *) WITH_BACKEND=0 ;;
  esac
fi

compose() {
  "$ENGINE" compose "$@"
}

for env_file in "$ROOT_DIR/front/.env" "$ROOT_DIR/back/.env"; do
  if [ ! -f "$env_file" ]; then
    example_file="${env_file}.example"
    if [ ! -f "$example_file" ]; then
      echo "ERROR: missing $example_file" >&2
      exit 1
    fi
    cp "$example_file" "$env_file"
    printf '%s\n' "[miminet] created $env_file from $example_file"
  fi
done

printf '%s\n' "[miminet] engine: $ENGINE"
printf '%s\n' "[miminet] starting frontend stack"
compose --project-directory "$ROOT_DIR/front" --env-file "$ROOT_DIR/front/.env" -f "$ROOT_DIR/front/docker-compose.yml" up -d --build

if [ "$WITH_BACKEND" = 1 ]; then
  printf '%s\n' "[miminet] starting backend (Linux kernel networking required)"
  compose --project-directory "$ROOT_DIR/back" -f "$ROOT_DIR/back/docker-compose.yml" --env-file "$ROOT_DIR/back/.env" up -d --build
else
  printf '%s\n' "[miminet] starting frontend stack only"
  printf '%s\n' "[miminet] backend emulation is disabled on this host; set MIMINET_WITH_BACKEND=1 to opt in"
fi

printf '%s\n' "[miminet] waiting for HTTP endpoint..."
i=0
while [ "$i" -lt 60 ]; do
  if command -v curl >/dev/null 2>&1 && curl -fsS http://127.0.0.1/ >/dev/null 2>&1; then
    printf '%s\n' "[miminet] ready: http://127.0.0.1/"
    exit 0
  fi
  i=$((i + 1))
  sleep 2
done

echo "ERROR: Miminet did not become ready within 120 seconds." >&2
compose --project-directory "$ROOT_DIR/front" --env-file "$ROOT_DIR/front/.env" -f "$ROOT_DIR/front/docker-compose.yml" ps >&2 || true
exit 1
