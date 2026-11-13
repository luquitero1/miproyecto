<?php
/**
 * Ejemplo de configuración. NO poner credenciales reales en este archivo.
 *
 * En el servidor, el script setup/05_base_datos.sh genera automáticamente
 * /etc/miproyecto/config.php (fuera del repositorio y de la carpeta pública)
 * con una contraseña aleatoria.
 *
 * Para desarrollo local se puede copiar este archivo a config/config.php
 * (está en .gitignore, nunca se sube a GitHub).
 */
return [
    'db' => [
        'host'   => 'localhost',
        'port'   => 3306,
        'socket' => '/run/mysqld/mysqld.sock', // si existe se usa el socket en lugar de TCP
        'name'   => 'miproyecto',
        'user'   => 'miproyecto_app',
        'pass'   => 'CAMBIAR_ESTA_CONTRASEÑA',
    ],
    'debug' => false, // true muestra el detalle de los errores en pantalla (sólo en pruebas)
];
