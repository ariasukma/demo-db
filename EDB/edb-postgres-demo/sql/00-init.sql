\set ON_ERROR_STOP on

CREATE ROLE replicator WITH REPLICATION LOGIN PASSWORD 'replicator_demo_password';
CREATE ROLE barman WITH SUPERUSER REPLICATION LOGIN PASSWORD 'barman_demo_password';
CREATE ROLE app_readonly NOLOGIN;
CREATE ROLE app_writer NOLOGIN;
CREATE ROLE app_admin NOLOGIN;
CREATE ROLE readonly_user LOGIN PASSWORD 'readonly_demo_password';
CREATE ROLE writer_user LOGIN PASSWORD 'writer_demo_password';
CREATE ROLE admin_user LOGIN PASSWORD 'admin_demo_password';

GRANT app_readonly TO readonly_user;
GRANT app_writer TO writer_user;
GRANT app_admin TO admin_user;

SELECT 'CREATE DATABASE demo'
WHERE NOT EXISTS (SELECT 1 FROM pg_database WHERE datname = 'demo')\gexec

\connect demo

CREATE SCHEMA IF NOT EXISTS app AUTHORIZATION postgres;
CREATE SCHEMA IF NOT EXISTS audit AUTHORIZATION postgres;

CREATE TABLE IF NOT EXISTS public.customers (
  id bigserial PRIMARY KEY,
  email text NOT NULL UNIQUE,
  full_name text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.orders (
  id bigserial PRIMARY KEY,
  customer_id bigint NOT NULL REFERENCES public.customers(id),
  status text NOT NULL CHECK (status IN ('new', 'paid', 'shipped', 'cancelled')),
  total_amount numeric(12,2) NOT NULL CHECK (total_amount >= 0),
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.order_events (
  id bigserial PRIMARY KEY,
  order_id bigint NOT NULL REFERENCES public.orders(id),
  event_type text NOT NULL,
  event_payload jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);

GRANT CONNECT ON DATABASE demo TO app_readonly, app_writer, app_admin;
GRANT USAGE ON SCHEMA public TO app_readonly, app_writer, app_admin;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO app_readonly;
GRANT SELECT, INSERT, UPDATE ON ALL TABLES IN SCHEMA public TO app_writer;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO app_writer;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO app_admin;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO app_admin;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO app_readonly;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT, INSERT, UPDATE ON TABLES TO app_writer;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO app_admin;
