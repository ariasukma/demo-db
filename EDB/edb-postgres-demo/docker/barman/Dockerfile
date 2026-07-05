FROM postgres:16-bookworm

LABEL project="edb-postgres-demo"

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        barman \
        ca-certificates \
        cron \
        openssh-client \
        procps \
        rsync \
    && rm -rf /var/lib/apt/lists/* \
    && mkdir -p /var/lib/barman /etc/barman.d \
    && if ! id barman >/dev/null 2>&1; then useradd --system --home-dir /var/lib/barman --shell /bin/bash barman; fi \
    && chown -R barman:barman /var/lib/barman /etc/barman.d

CMD ["sleep", "infinity"]
