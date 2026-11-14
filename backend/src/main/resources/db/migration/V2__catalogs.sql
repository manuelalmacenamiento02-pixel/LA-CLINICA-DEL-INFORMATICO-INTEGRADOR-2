INSERT INTO roles(code,name) VALUES
 ('ADMINISTRADOR','Administrador'),('PERSONAL DE ATENCIÓN','Personal de Atención'),('TÉCNICO','Técnico');
INSERT INTO permissions(code,description) VALUES
 ('dashboard','Ver dashboard'),('clients','Gestionar clientes'),('equipment','Gestionar equipos'),
 ('orders','Gestionar órdenes'),('assign-technicians','Asignar técnicos'),
 ('assigned-orders','Consultar órdenes asignadas'),('attend-orders','Atender órdenes'),
 ('ai-prediagnosis','Usar prediagnóstico IA'),('service-tracking','Consultar seguimiento'),
 ('service-indicators','Consultar indicadores'),('users','Gestionar usuarios'),('settings','Configuración');
INSERT INTO role_permissions SELECT 'ADMINISTRADOR',code FROM permissions;
INSERT INTO role_permissions(role_code,permission_code) VALUES
 ('PERSONAL DE ATENCIÓN','dashboard'),('PERSONAL DE ATENCIÓN','clients'),
 ('PERSONAL DE ATENCIÓN','equipment'),('PERSONAL DE ATENCIÓN','orders'),('PERSONAL DE ATENCIÓN','service-tracking'),
 ('TÉCNICO','dashboard'),('TÉCNICO','assigned-orders'),('TÉCNICO','attend-orders'),
 ('TÉCNICO','ai-prediagnosis'),('TÉCNICO','service-tracking');
INSERT INTO order_statuses(code,name,terminal) VALUES
 ('PENDIENTE','Pendiente',false),('ASIGNADA','Asignada',false),('EN_ATENCION','En atención',false),
 ('FINALIZADA','Finalizada',false),('CERRADA','Cerrada',true),('CANCELADA','Cancelada',true);
INSERT INTO order_status_transitions VALUES
 ('PENDIENTE','ASIGNADA'),('PENDIENTE','CANCELADA'),('ASIGNADA','EN_ATENCION'),('ASIGNADA','CANCELADA'),
 ('EN_ATENCION','FINALIZADA'),('EN_ATENCION','CANCELADA'),('FINALIZADA','EN_ATENCION'),('FINALIZADA','CERRADA');
