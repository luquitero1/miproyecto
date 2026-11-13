<?php
require __DIR__ . '/../src/app.php';

$filas = [
    'Servidor web' => $_SERVER['SERVER_SOFTWARE'] ?? '',
    'Dominio' => $_SERVER['HTTP_HOST'] ?? '',
    'PHP' => PHP_VERSION,
];
try {
    $filas['Base de datos'] = db()->query('SELECT VERSION()')->fetchColumn();
    $filas['Registros en tabla equipos'] = db()->query('SELECT COUNT(*) FROM equipos')->fetchColumn();
    $ok = true;
} catch (Throwable $ex) {
    $filas['Base de datos'] = 'Error de conexión';
    $ok = false;
}
http_response_code($ok ? 200 : 503);

cabecera('Estado del servidor');
?>
<h1>Estado del servidor</h1>
<div class="aviso <?= $ok ? '' : 'error' ?>"><?= $ok ? 'Todo funcionando' : 'Hay problemas' ?></div>
<table>
    <?php foreach ($filas as $nombre => $valor): ?>
        <tr><th><?= e($nombre) ?></th><td><?= e($valor) ?></td></tr>
    <?php endforeach; ?>
</table>
<?php pie();
