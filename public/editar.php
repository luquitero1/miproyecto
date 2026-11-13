<?php
/** Modificación de un equipo existente. */
declare(strict_types=1);
require __DIR__ . '/../src/bootstrap.php';
require __DIR__ . '/../src/formulario.php';

$id = filter_input(INPUT_GET, 'id', FILTER_VALIDATE_INT, ['options' => ['min_range' => 1]]);
if (!$id) {
    flash('Equipo no especificado.', 'error');
    redirigir('/');
}

$stmt = db()->prepare('SELECT * FROM equipos WHERE id = :id');
$stmt->execute(['id' => $id]);
$datos = $stmt->fetch();
if (!$datos) {
    flash('El equipo solicitado no existe (puede haber sido eliminado).', 'error');
    redirigir('/');
}
$codigoOriginal = $datos['codigo'];
$errores = [];

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    csrf_verificar();
    [$datos, $errores] = validar_equipo($_POST);
    if (!$errores) {
        try {
            $stmt = db()->prepare(
                'UPDATE equipos SET codigo = :codigo, tipo = :tipo, marca = :marca, modelo = :modelo,
                        numero_serie = :numero_serie, ubicacion = :ubicacion, responsable = :responsable,
                        estado = :estado, fecha_alta = :fecha_alta, observaciones = :observaciones
                 WHERE id = :id'
            );
            $stmt->execute($datos + ['id' => $id]);
            flash("Equipo {$datos['codigo']} actualizado correctamente.");
            redirigir('/');
        } catch (PDOException $ex) {
            if (!es_duplicado($ex)) {
                throw $ex;
            }
            $errores['codigo'] = 'Ya existe otro equipo con ese código.';
        }
    }
}

cabecera('Modificar ' . $codigoOriginal);
?>
<section class="encabezado">
    <div>
        <h1>Modificar equipo <?= e($codigoOriginal) ?></h1>
        <p class="sutil">Los campos marcados con <span class="req">*</span> son obligatorios.</p>
    </div>
</section>
<?php if ($errores): ?>
    <div class="aviso aviso--error">Revisá los campos marcados.</div>
<?php endif; ?>
<?php formulario_equipo($datos, $errores, '/editar.php?id=' . $id, 'Guardar cambios'); ?>
<?php pie();
