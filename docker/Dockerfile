# mysecondbrain — All-in-One Image (gleicher Kern wie LXC, supervisord statt systemd)
FROM debian:12-slim

ARG WITH_WHISPER=false
ENV DEBIAN_FRONTEND=noninteractive TZ=Europe/Berlin

# --- Basis-Pakete ---
RUN apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates curl gnupg jq git cron supervisor procps iproute2 tzdata \
      python3 python3-venv python3-pip \
      ffmpeg tesseract-ocr tesseract-ocr-deu poppler-utils inotify-tools \
      apache2-utils restic \
    && rm -rf /var/lib/apt/lists/*

# --- Node 20 + Claude CLI ---
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
    && apt-get install -y --no-install-recommends nodejs \
    && npm install -g @anthropic-ai/claude-code \
    && rm -rf /var/lib/apt/lists/* /root/.npm

# --- ntfy (statisches Binary, neueste Release) ---
RUN set -eux; \
    V=$(curl -fsSL https://api.github.com/repos/binwiederhier/ntfy/releases/latest | jq -r .tag_name | sed 's/^v//'); \
    curl -fsSL "https://github.com/binwiederhier/ntfy/releases/download/v${V}/ntfy_${V}_linux_amd64.tar.gz" -o /tmp/ntfy.tgz; \
    tar -C /tmp -xzf /tmp/ntfy.tgz; \
    install -m0755 "/tmp/ntfy_${V}_linux_amd64/ntfy" /usr/bin/ntfy; \
    rm -rf /tmp/ntfy*

# --- Syncthing (statisches Binary) ---
RUN set -eux; \
    V=$(curl -fsSL https://api.github.com/repos/syncthing/syncthing/releases/latest | jq -r .tag_name | sed 's/^v//'); \
    curl -fsSL "https://github.com/syncthing/syncthing/releases/download/v${V}/syncthing-linux-amd64-v${V}.tar.gz" -o /tmp/st.tgz; \
    tar -C /tmp -xzf /tmp/st.tgz; \
    install -m0755 "/tmp/syncthing-linux-amd64-v${V}/syncthing" /usr/bin/syncthing; \
    rm -rf /tmp/st* /tmp/syncthing-*

# --- Tailscale (statische Binaries, tailscale-CDN) ---
RUN set -eux; \
    TB=$(curl -fsSL "https://pkgs.tailscale.com/stable/?mode=json" | jq -r .Tarballs.amd64); \
    curl -fsSL "https://pkgs.tailscale.com/stable/${TB}" -o /tmp/ts.tgz; \
    tar -C /tmp -xzf /tmp/ts.tgz; \
    D=$(basename "$TB" .tgz); \
    install -m0755 "/tmp/${D}/tailscale" /usr/bin/tailscale; \
    install -m0755 "/tmp/${D}/tailscaled" /usr/bin/tailscaled; \
    rm -rf /tmp/ts* /tmp/tailscale_*

# --- Radicale (venv) ---
RUN python3 -m venv /opt/radicale-venv \
    && /opt/radicale-venv/bin/pip install --no-cache-dir --upgrade pip \
    && /opt/radicale-venv/bin/pip install --no-cache-dir radicale "passlib[bcrypt]" bcrypt

# --- whisper.cpp (optional) ---
RUN if [ "$WITH_WHISPER" = "true" ]; then \
      apt-get update && apt-get install -y --no-install-recommends build-essential cmake \
      && git clone --depth 1 https://github.com/ggerganov/whisper.cpp /opt/whisper.cpp \
      && cmake -S /opt/whisper.cpp -B /opt/whisper.cpp/build && cmake --build /opt/whisper.cpp/build -j --config Release \
      && bash /opt/whisper.cpp/models/download-ggml-model.sh small \
      && rm -rf /var/lib/apt/lists/* ; \
    fi

# --- App (gleicher Kern wie LXC) ---
COPY opt-kb/ /opt/kb/
COPY vault-seed/ /opt/kb/vault-seed/
COPY setup/ /opt/kb/setup/
COPY openwa/ /opt/kb/openwa/
RUN chmod +x /opt/kb/*.sh /opt/kb/gen_ics.py /opt/kb/kb-ask /opt/kb/kb-ingest /opt/kb/kb-doctor /opt/kb/configure.sh \
    && ln -sf /opt/kb/kb-ask /usr/local/bin/kb-ask \
    && ln -sf /opt/kb/kb-ingest /usr/local/bin/kb-ingest \
    && ln -sf /opt/kb/kb-doctor /usr/local/bin/kb-doctor \
    && ln -sf /opt/kb/configure.sh /usr/local/bin/kb-configure

COPY docker/entrypoint.sh /usr/local/bin/kb-entrypoint
COPY docker/tailscale-run.sh /opt/kb/tailscale-run.sh
COPY docker/supervisord.conf /etc/supervisor/conf.d/kb.conf
RUN chmod +x /usr/local/bin/kb-entrypoint /opt/kb/tailscale-run.sh

EXPOSE 5232 8080 8384
VOLUME /data
ENTRYPOINT ["/usr/local/bin/kb-entrypoint"]
