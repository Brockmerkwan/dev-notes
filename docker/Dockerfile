FROM python:3.12-slim
WORKDIR /app

# Tools + UTF-8 locale
RUN apt-get update \
 && apt-get install -y --no-install-recommends curl jq ca-certificates locales \
 && rm -rf /var/lib/apt/lists/* \
 && sed -i 's/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen \
 && locale-gen

ENV LANG=en_US.UTF-8 \
    LANGUAGE=en_US:en \
    LC_ALL=en_US.UTF-8

# Try to install ollama CLI (service stays on host)
RUN curl -fsSL https://ollama.com/install.sh | sh || true

# Bring in watcher + heartbeat
COPY tools/alerts/*.py tools/alerts/*.sh /app/

# Fallback config inside the image (you can still pass/override via env/volume)
RUN mkdir -p /app/config \
 && printf "topic: brock-live-feed\nmin_score: 0.4\nmodel: llama3.1:latest\nfeeds:\n  - https://hnrss.org/frontpage\n  - https://github.blog/changelog/feed/\n  - https://status.github.com/messages.atom\n  - https://aws.amazon.com/new/feed/\nkeywords:\n  - devops\n  - automation\n  - macos\n  - homebrew\n  - ollama\n  - llm\n  - github actions\n  - docker\n  - swift\n" > /app/rss.yaml

# Python deps
RUN pip install --no-cache-dir feedparser requests pyyaml

# Defaults (overridable at docker run)
ENV RSS_CONF=/app/rss.yaml \
    OLLAMA_HOST=http://host.docker.internal:11434 \
    MIN_SCORE=0.4 \
    MAX_SEND=8 \
    AI_TIMEOUT=10 \
    BATCH_MODE=1 \
    HEARTBEAT_INTERVAL=3600

# Loop: watcher -> heartbeat -> sleep
CMD bash -lc '
  while true; do
    echo "[$(date +%F_%T)] 🧠 running rss_ai_watcher.py"
    python3 /app/rss_ai_watcher.py || true
    echo "[$(date +%F_%T)] ❤️ sending heartbeat"
    RSS_CONF="${RSS_CONF}" bash /app/heartbeat.sh || true
    echo "sleeping ${HEARTBEAT_INTERVAL}s..."
    sleep "${HEARTBEAT_INTERVAL}"
  done
'
