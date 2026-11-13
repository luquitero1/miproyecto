-- Datos de ejemplo (sólo se cargan si la tabla está vacía; ver setup/05_base_datos.sh).
INSERT INTO equipos (codigo, tipo, marca, modelo, numero_serie, ubicacion, responsable, estado, fecha_alta, observaciones) VALUES
('SRV-001', 'Servidor',  'Dell',     'PowerEdge R250',    'DL7X2K3', 'Sala de servidores', 'Ana Gómez',    'Operativo',         '2025-03-10', 'Servidor principal: Apache + MariaDB'),
('SW-001',  'Switch',    'TP-Link',  'TL-SG1024D',        'TP99812', 'Rack principal',     'Bruno Díaz',   'Operativo',         '2025-03-10', '24 puertos gigabit'),
('PC-001',  'PC',        'Lenovo',   'ThinkCentre M70q',  'LNV10021', 'Oficina desarrollo', 'Carla Méndez', 'Operativo',         '2025-04-02', NULL),
('PC-002',  'PC',        'HP',       'ProDesk 400 G7',    'HP55120',  'Oficina desarrollo', 'Diego Rivas',  'En reparación',     '2024-11-18', 'Fuente de alimentación con fallas'),
('NB-001',  'Notebook',  'Lenovo',   'ThinkPad E14',      'LNV55871', 'Oficina respaldos',  'Elena Suárez', 'Operativo',         '2025-06-21', NULL),
('IMP-001', 'Impresora', 'Brother',  'HL-L2350DW',        'BR773310', 'Recepción',          NULL,           'Fuera de servicio', '2023-08-05', 'Atasco recurrente de papel');
