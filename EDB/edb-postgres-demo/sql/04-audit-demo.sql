\set ON_ERROR_STOP on
\connect demo

CREATE TABLE IF NOT EXISTS audit.demo_audit_log (
  id bigserial PRIMARY KEY,
  username text NOT NULL DEFAULT current_user,
  action text NOT NULL,
  table_name text NOT NULL,
  row_id bigint,
  at timestamptz NOT NULL DEFAULT now()
);

CREATE OR REPLACE FUNCTION audit.log_order_change()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = audit, public, pg_catalog
AS $$
BEGIN
  INSERT INTO audit.demo_audit_log(action, table_name, row_id)
  VALUES (TG_OP, TG_TABLE_SCHEMA || '.' || TG_TABLE_NAME, COALESCE(NEW.id, OLD.id));
  RETURN COALESCE(NEW, OLD);
END;
$$;

DROP TRIGGER IF EXISTS trg_orders_audit ON public.orders;
CREATE TRIGGER trg_orders_audit
AFTER INSERT OR UPDATE OR DELETE ON public.orders
FOR EACH ROW EXECUTE FUNCTION audit.log_order_change();

ALTER SYSTEM SET log_statement = 'ddl';
ALTER SYSTEM SET log_connections = 'on';
ALTER SYSTEM SET log_disconnections = 'on';
