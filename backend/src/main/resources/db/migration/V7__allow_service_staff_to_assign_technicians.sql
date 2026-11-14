INSERT INTO role_permissions(role_code, permission_code)
VALUES ('PERSONAL DE ATENCIÓN', 'assign-technicians')
ON CONFLICT DO NOTHING;
