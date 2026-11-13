<?php
/** Alta de un equipo (formulario de registro). */
declare(strict_types=1);
require __DIR__ . '/../src/bootstrap.php';
require __DIR__ . '/../src/formulario.php';

$datos = ['estado' => 'Operativo', 'fecha_alta' => date('Y-m-d')];
$errores = [];

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    csrf_verificar();
    [$datos, $errores] = validar_equipo($_POST);
    if (!$errores) {
        try {
            $stmt = db()->prepare(
                'INSERT INTO equipos (codigo, tipo, marca, modelo, numero_serie, ubicacion, responsable, estado, fecha_alta, observaciones)
                 VALUES (:codigo, :tipo, :marca, :modelo, :numero_serie, :ubicacion, :responsable, :estado, :fecha_alta, :observaciones)'
            );
            $stmt->execute($datos);
            flash("Equipo {$datos['codigo']} registrado correctamente.");
            redirigir('/');
        } catch (PDOException $ex) {
            if (!es_duplicado($ex)) {
                throw $ex;
            }
            $errores['codigo'] = 'Ya existe un equipo con ese código.';
        }
    }
}

cabecera('Registrar equipo', 'nuevo');
?>
<section class="encabezado">
    <div>
        <h1>Registrar equipo</h1>
        <p class="sutil">Los campos marcados con <span class="req">*</span> son obligatorios.</p>
    </div>
</section>
<?php if ($errores): ?>
    <div class="aviso aviso--error">Revisá los campos marcados.</div>
<?php endif; ?>
<?php formulario_equipo($datos, $errores, '/crear.php', 'Guardar equipo'); ?>
<?php pie();
