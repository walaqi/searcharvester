FROM searxng/searxng:latest

USER root

# Bake in a minimal settings.yml with placeholders that are replaced at
# runtime by entrypoint.sh via SEARXNG_SECRET and VALKEY_URL env vars.
# When running locally via docker compose, the bind mount
# (./config.yaml:/etc/searxng/settings.yml:ro) overrides this file, so
# the entrypoint skips injection and behaviour is identical to before.
COPY settings.yml /etc/searxng/settings.yml
COPY entrypoint.sh /custom-entrypoint.sh
RUN chmod +x /custom-entrypoint.sh

ENTRYPOINT ["/custom-entrypoint.sh"]
