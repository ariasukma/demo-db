COMPOSE ?= docker compose

.PHONY: build-images build pull up down ps logs init backup restore maintenance optimization monitoring security replication efm pgd clean purge nuke config

build-images:
	./scripts/00-build-demo-images.sh
	$(COMPOSE) --env-file .env build barman

build: build-images

pull:
	./scripts/00-build-demo-images.sh

up: build-images
	$(COMPOSE) --env-file .env up -d

down:
	$(COMPOSE) --env-file .env down --remove-orphans

ps:
	$(COMPOSE) --env-file .env ps

logs:
	$(COMPOSE) --env-file .env logs -f --tail=200

init:
	./scripts/00-init-demo.sh

config:
	$(COMPOSE) --env-file .env config

backup:
	./scripts/01-backup-full.sh

restore:
	./scripts/04-restore-latest.sh

maintenance:
	./scripts/05-maintenance-job.sh

optimization:
	./scripts/06-optimization-demo.sh

monitoring:
	./scripts/07-monitoring-alert-demo.sh

security:
	./scripts/08-security-demo.sh

replication:
	./scripts/09-replication-demo.sh

efm:
	./scripts/10-efm-demo.sh

pgd:
	./scripts/11-pgd-demo.sh

clean:
	$(COMPOSE) --env-file .env down -v --remove-orphans
	rm -rf logs tmp reports

purge: clean
	docker image rm edb-demo-postgres:16-bookworm || true
	docker image rm edb-demo-haproxy:2.9 || true
	docker image rm edb-demo-prometheus:v2.54.1 || true
	docker image rm edb-demo-grafana:11.1.4 || true
	docker image rm edb-demo-postgres-exporter:v0.15.0 || true
	docker image rm edb-demo-barman:local || true

nuke: purge
	docker builder prune --filter "label=project=edb-postgres-demo" -f || true
