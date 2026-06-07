#!/bin/sh
# Custom SearXNG entrypoint.
# Injects SEARXNG_SECRET and VALKEY_URL into settings.yml at runtime.
# If settings.yml is read-only (local bind-mount), sed is skipped — the
# mounted config.yaml already has the correct values.
set -e

SETTINGS="/etc/searxng/settings.yml"

if [ -w "$SETTINGS" ]; then
    SECRET="${SEARXNG_SECRET:-please-change-me-to-a-random-32-char-string}"
    REDIS="${VALKEY_URL:-redis://redis:6379/0}"
    sed -i "s|SEARXNG_SECRET_PLACEHOLDER|${SECRET}|g" "$SETTINGS"
    sed -i "s|VALKEY_URL_PLACEHOLDER|${REDIS}|g" "$SETTINGS"
    echo "SearXNG: injected runtime config (secret + redis url)"
else
    echo "SearXNG: settings.yml is read-only (bind mount), skipping env injection"
fi

UPSTREAM_EP=$(find /usr/local/searxng /searxng -name "docker-entrypoint.sh" 2>/dev/null | head -1)
if [ -z "$UPSTREAM_EP" ]; then
    UPSTREAM_EP=$(find / -maxdepth 6 -name "docker-entrypoint.sh" 2>/dev/null | grep -v proc | head -1)
fi
exec "$UPSTREAM_EP" "$@"
