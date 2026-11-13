<?php
require __DIR__ . '/../src/app.php';

$datos = ['estado' => 'Operativo'];
$error = null;
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $datos = datos_del_formulario();
    $error = guardar('INSERT INTO equipos (' . implode(', ', CAMPOS) . ') VALUES (:' . implode(', :', CAMPOS) . ')', $datos);
}

cabecera('Registrar equipo');
?>
<h1>Registrar equipo</h1>
<?php if ($error): ?><div class="aviso error"><?= e($error) ?></div><?php endif; ?>
<?php formulario($datos, 'Guardar equipo'); ?>
<?php pie();
