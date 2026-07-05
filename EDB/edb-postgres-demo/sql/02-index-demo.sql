\set ON_ERROR_STOP on
\connect demo

CREATE TABLE IF NOT EXISTS public.large_order_search (
  id bigserial PRIMARY KEY,
  tenant_id int NOT NULL,
  status text NOT NULL,
  search_key text NOT NULL,
  payload text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

INSERT INTO public.large_order_search (tenant_id, status, search_key, payload, created_at)
SELECT (random() * 25)::int + 1,
       (ARRAY['new', 'paid', 'shipped', 'cancelled'])[1 + (random() * 3)::int],
       md5(gs::text),
       repeat(md5(random()::text), 4),
       now() - ((random() * 90)::int || ' days')::interval
FROM generate_series(1, 50000) AS gs
WHERE NOT EXISTS (SELECT 1 FROM public.large_order_search);

ANALYZE public.large_order_search;
