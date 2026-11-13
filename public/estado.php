<?php
/** Verificación de Apache + PHP + base de datos (Parte 3 del práctico). */
declare(strict_types=1);
require __DIR__ . '/../src/bootstrap.php';

$chequeos = [];
$chequeos[] = ['Servidor web', $_SERVER['SERVER_SOFTWARE'] ?? php_sapi_name(), true];
$chequeos[] = ['Nombre de dominio', $_SERVER['HTTP_HOST'] ?? '—', true];
$chequeos[] = ['PHP', PHP_VERSION . ' (' . php_sapi_name() . ')', true];
$chequeos[] = ['Extensión pdo_mysql', extension_loaded('pdo_mysql') ? 'cargada' : 'NO cargada', extension_loaded('pdo_mysql')];

try {
    $pdo = db();
    $version = $pdo->query('SELECT VERSION()')->fetchColumn();
    $base = $pdo->query('SELECT DATABASE()')->fetchColumn();
    $usuario = $pdo->query('SELECT CURRENT_USER()')->fetchColumn();
    $registros = $pdo->query('SELECT COUNT(*) FROM equipos')->fetchColumn();
    $chequeos[] = ['Conexión a la base de datos', 'OK — ' . $pdo->getAttribute(PDO::ATTR_CONNECTION_STATUS), true];
    $chequeos[] = ['Motor de base de datos', $version, true];
    $chequeos[] = ['Base / usuario', "$base / $usuario", true];
    $chequeos[] = ['Registros en tabla equipos', (string)$registros, true];
} catch (Throwable $ex) {
    error_log('[miproyecto] estado.php: ' . $ex->getMessage());
    $chequeos[] = ['Conexión a la base de datos', 'ERROR — revisar /var/log/apache2/miproyecto_error.log', false];
}

$chequeos[] = ['Hora del servidor', date('d/m/Y H:i:s T'), true];
$chequeos[] = ['Commit desplegado', commit_desplegado() ?? 'sin información de Git', true];

$todoOk = !in_array(false, array_column($chequeos, 2), true);
http_response_code($todoOk ? 200 : 503);

cabecera('Estado del servidor', 'estado');
?>
<section class="encabezado">
    <div>
        <h1>Estado del servidor</h1>
        <p class="sutil">Comprobación de Apache, PHP y MariaDB/MySQL.</p>
    </div>
    <span class="etiqueta etiqueta--<?= $todoOk ? 'operativo' : 'fuera' ?> etiqueta--grande">
        <?= $todoOk ? 'Todo funcionando' : 'Hay problemas' ?>
    </span>
</section>
<div class="tarjeta tabla-envoltura">
    <table class="tabla">
        <tbody>
        <?php foreach ($chequeos as [$nombre, $valor, $ok]): ?>
            <tr>
                <th scope="row"><?= e($nombre) ?></th>
                <td><?= e($valor) ?></td>
                <td class="col-estado"><?= $ok ? '✔' : '✘' ?></td>
            </tr>
        <?php endforeach; ?>
        </tbody>
    </table>
</div>
<?php pie();
