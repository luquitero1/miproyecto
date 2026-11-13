CREATE TABLE IF NOT EXISTS equipos (
    id             INT UNSIGNED  NOT NULL AUTO_INCREMENT,
    codigo         VARCHAR(20)   NOT NULL,
    tipo           VARCHAR(20)   NOT NULL,
    marca          VARCHAR(60)   NOT NULL,
    modelo         VARCHAR(80)   NOT NULL,
    numero_serie   VARCHAR(80)   NULL,
    ubicacion      VARCHAR(80)   NOT NULL,
    responsable    VARCHAR(80)   NULL,
    estado         VARCHAR(20)   NOT NULL DEFAULT 'Operativo',
    fecha_alta     DATE          NOT NULL,
    observaciones  TEXT          NULL,
    creado_en      TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    actualizado_en TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE KEY uk_equipos_codigo (codigo)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
