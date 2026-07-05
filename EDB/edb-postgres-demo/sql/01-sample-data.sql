\set ON_ERROR_STOP on
\connect demo

INSERT INTO public.customers (email, full_name)
SELECT format('customer%04s@example.test', gs), format('Demo Customer %s', gs)
FROM generate_series(1, 100) AS gs
ON CONFLICT (email) DO NOTHING;

INSERT INTO public.orders (customer_id, status, total_amount, created_at)
SELECT c.id,
       (ARRAY['new', 'paid', 'shipped', 'cancelled'])[1 + (random() * 3)::int],
       round((10 + random() * 990)::numeric, 2),
       now() - ((random() * 30)::int || ' days')::interval
FROM public.customers c
CROSS JOIN generate_series(1, 20) gs
WHERE NOT EXISTS (SELECT 1 FROM public.orders)
ON CONFLICT DO NOTHING;

INSERT INTO public.order_events (order_id, event_type, event_payload)
SELECT o.id, 'created', jsonb_build_object('source', 'seed')
FROM public.orders o
WHERE NOT EXISTS (
  SELECT 1 FROM public.order_events e WHERE e.order_id = o.id AND e.event_type = 'created'
);

SELECT 'customers' AS table_name, count(*) AS rows FROM public.customers
UNION ALL
SELECT 'orders', count(*) FROM public.orders
UNION ALL
SELECT 'order_events', count(*) FROM public.order_events;
