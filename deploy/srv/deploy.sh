#!/usr/bin/env bash
# Deploys the Taniin multiplayer server to srv (ssh alias "srv").
# Usage: deploy/srv/deploy.sh            # code + service only
#        deploy/srv/deploy.sh --env      # also (re)write /etc/taniin/mp.env from ../../.env
set -euo pipefail
cd "$(dirname "$0")/../.."
HOST=${TANIIN_SRV_HOST:-srv}

tar -C contracts -czf - lib scripts db package.json package-lock.json \
  | ssh "$HOST" 'mkdir -p /opt/taniin-mp && tar -C /opt/taniin-mp -xzf - && cd /opt/taniin-mp && npm ci --omit=dev --no-audit --no-fund --loglevel=error'

if [[ "${1:-}" == "--env" ]]; then
  # .env values contain '&' (Neon URLs), so read keys instead of sourcing the file.
  envval() { grep -E "^$1=" .env | tail -1 | cut -d= -f2-; }
  DATABASE_URL=$(envval DATABASE_URL)
  GROQ_API_KEY=$(envval GROQ_API_KEY)
  GROQ_MODEL=$(envval GROQ_MODEL)
  printf '%s\n' \
    "DATABASE_URL=${DATABASE_URL//sslmode=require/sslmode=verify-full}" \
    "GROQ_API_KEY=${GROQ_API_KEY:-}" \
    "GROQ_MODEL=${GROQ_MODEL:-openai/gpt-oss-20b}" \
    "TANIIN_ALLOWED_ORIGIN=https://taniin.rahmateka.my.id" \
    "TANIIN_GAME_API_HOST=127.0.0.1" \
    "TANIIN_GAME_API_PORT=7690" \
    "TANIIN_MULTIPLAYER_ONLY=true" \
    | ssh "$HOST" 'install -d -m 700 /etc/taniin && umask 077 && cat > /etc/taniin/mp.env'
fi

scp -q deploy/srv/taniin-mp.service "$HOST":/etc/systemd/system/taniin-mp.service
scp -q deploy/srv/Caddyfile.taniin-mp "$HOST":/etc/caddy/taniin-mp.caddy
ssh "$HOST" '
  set -e
  grep -q "import /etc/caddy/taniin-mp.caddy" /etc/caddy/Caddyfile || {
    cp /etc/caddy/Caddyfile /etc/caddy/Caddyfile.sebelum-taniin
    printf "\nimport /etc/caddy/taniin-mp.caddy\n" >> /etc/caddy/Caddyfile
  }
  caddy validate --config /etc/caddy/Caddyfile --adapter caddyfile >/dev/null
  systemctl reload caddy
  systemctl daemon-reload
  systemctl enable --now taniin-mp.service
  systemctl restart taniin-mp.service
  sleep 2
  curl -fsS -H "Host: taniin-mp.rahmateka.my.id" http://127.0.0.1/health
'
echo
