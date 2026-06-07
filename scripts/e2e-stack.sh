#!/usr/bin/env bash
# scripts/e2e-stack.sh — E2E test stack lifecycle.
set -euo pipefail
cd "$(dirname "$0")/.."

CMD="${1:-}"
COMPOSE="docker-compose.test.yml"
ENVFILE=".env.test"

[ -f "$ENVFILE" ] || { echo "missing $ENVFILE — run /infra to generate it"; exit 1; }
set -a; . "./$ENVFILE"; set +a

if [ "${E2E_STACK_EXTERNAL:-}" = "1" ]; then
  echo "[e2e-stack] E2E_STACK_EXTERNAL=1 — targeting deployed Azure app at ${E2E_BASE_URL:-<unset>}"
  case "$CMD" in
    up)
      echo "[e2e-stack] Verifying Azure app is reachable..."
      for i in $(seq 1 10); do
        if curl -fs "${E2E_BASE_URL:-http://localhost:8080}/health" >/dev/null 2>&1 \
        || curl -fs "${E2E_BASE_URL:-http://localhost:8080}" >/dev/null 2>&1; then
          echo "[e2e-stack] Azure app reachable."
          exit 0
        fi
        sleep 3
      done
      echo "[e2e-stack] WARNING: Azure app not reachable. Classify as AZURE UNAVAILABLE."
      exit 1
      ;;
    down)
      echo "[e2e-stack] External mode — nothing to stop."
      exit 0
      ;;
    *)
      echo "usage: e2e-stack.sh up|down"
      exit 1
      ;;
  esac
fi

if docker compose version >/dev/null 2>&1; then DC="docker compose"; else DC="docker-compose"; fi

case "$CMD" in
  up)
    echo "[e2e-stack] building + starting local app containers..."
    $DC -f "$COMPOSE" --env-file "$ENVFILE" up -d --build
    for i in $(seq 1 30); do
      if curl -fs "${E2E_BASE_URL:-http://localhost:8080}" >/dev/null 2>&1; then
        echo "[e2e-stack] up."
        exit 0
      fi
      sleep 3
    done
    echo "[e2e-stack] ERROR: app did not become healthy — STACK NOT READY"
    exit 1
    ;;
  down)
    echo "[e2e-stack] stopping local containers..."
    $DC -f "$COMPOSE" --env-file "$ENVFILE" down
    echo "[e2e-stack] down."
    ;;
  *)
    echo "usage: e2e-stack.sh up|down"
    exit 1
    ;;
esac
