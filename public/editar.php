<?php
require __DIR__ . '/../src/app.php';

$id = (int)($_GET['id'] ?? 0);
$consulta = db()->prepare('SELECT * FROM equipos WHERE id = ?');
$consulta->execute([$id]);
$datos = $consulta->fetch() ?: ir_al_inicio();
$codigo = $datos['codigo'];
$error = null;

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $datos = datos_del_formulario();
    $asignaciones = implode(', ', array_map(fn($c) => "$c = :$c", CAMPOS));
    $error = guardar("UPDATE equipos SET $asignaciones WHERE id = :id", $datos + ['id' => $id]);
}

cabecera('Modificar ' . $codigo);
?>
<h1>Modificar equipo <?= e($codigo) ?></h1>
<?php if ($error): ?><div class="aviso error"><?= e($error) ?></div><?php endif; ?>
<?php formulario($datos, 'Guardar cambios'); ?>
<?php pie();
