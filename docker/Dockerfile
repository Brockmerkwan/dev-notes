FROM python:3.12-slim
RUN apt-get update && apt-get install -y --no-install-recommends \
      curl jq ca-certificates locales \
  && sed -i 's/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen \
  && locale-gen \
  && rm -rf /var/lib/apt/lists/*
ENV LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8
WORKDIR /app
# Optional local Ollama (container) – if OLLAMA_HOST is not set we can start local serve
RUN curl -fsSL https://ollama.com/install.sh | sh || true
COPY tools/alerts/*.py tools/alerts/*.sh /app/
# Minimal baked-in config; you can override with RSS_CONF=/data/rss.yaml
RUN printf "topic: brock-live-feed\nmin_score: 0.6\nfeeds:\n  - https://hnrss.org/frontpage\n" > /app/rss.yaml
RUN pip install --no-cache-dir feedparser requests pyyaml
COPY docker/start.sh /app/start.sh
RUN chmod +x /app/start.sh /app/heartbeat.sh || true
ENV RSS_CONF=/app/rss.yaml \
    OLLAMA_MODEL=llama3.1:8b \
    RSS_MAX_PUSH=8 \
    RSS_PUSH_BATCH=1
CMD ["/app/start.sh"]
