ALTER TABLE service_orders
    ADD COLUMN received_at date;

UPDATE service_orders
SET received_at = created_at::date
WHERE received_at IS NULL;

ALTER TABLE service_orders
    ALTER COLUMN received_at SET DEFAULT CURRENT_DATE,
    ALTER COLUMN received_at SET NOT NULL;

INSERT INTO order_status_transitions(from_status, to_status)
VALUES ('PENDIENTE', 'EN_ATENCION')
ON CONFLICT DO NOTHING;

INSERT INTO order_status_history(order_id,from_status,to_status,changed_by,reason,changed_at)
SELECT so.id,NULL,so.status_code,so.received_by,'Estado registrado antes del historial',so.created_at
FROM service_orders so
WHERE NOT EXISTS (
    SELECT 1 FROM order_status_history history WHERE history.order_id=so.id
);
