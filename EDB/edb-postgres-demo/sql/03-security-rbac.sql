\set ON_ERROR_STOP on
\connect demo

GRANT USAGE ON SCHEMA public TO app_readonly, app_writer, app_admin;
GRANT SELECT ON public.customers, public.orders, public.order_events TO app_readonly;
GRANT SELECT, INSERT, UPDATE ON public.customers, public.orders, public.order_events TO app_writer;
GRANT USAGE, SELECT ON SEQUENCE public.customers_id_seq, public.orders_id_seq, public.order_events_id_seq TO app_writer;
GRANT ALL PRIVILEGES ON SCHEMA public TO app_admin;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO app_admin;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO app_admin;

REVOKE CREATE ON SCHEMA public FROM PUBLIC;
REVOKE ALL ON DATABASE demo FROM PUBLIC;
