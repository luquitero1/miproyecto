<?php
require __DIR__ . '/../src/app.php';

$equipos = db()->query('SELECT * FROM equipos ORDER BY codigo')->fetchAll();

cabecera('Inventario');
?>
<h1>Inventario de equipos</h1>
<div class="aviso">Versión 1.1.0: actualizada desde GitHub mediante <code>deploy.sh</code>.</div>
<p><a class="boton" href="/crear.php">+ Registrar equipo</a></p>

<table>
    <tr>
        <th>Código</th><th>Tipo</th><th>Marca / Modelo</th><th>N° de serie</th><th>Ubicación</th>
        <th>Responsable</th><th>Estado</th><th>Alta</th><th>Observaciones</th><th></th>
    </tr>
    <?php foreach ($equipos as $eq): ?>
        <tr>
            <td><strong><?= e($eq['codigo']) ?></strong></td>
            <td><?= e($eq['tipo']) ?></td>
            <td><?= e($eq['marca'] . ' ' . $eq['modelo']) ?></td>
            <td><?= e($eq['numero_serie']) ?></td>
            <td><?= e($eq['ubicacion']) ?></td>
            <td><?= e($eq['responsable']) ?></td>
            <td><?= e($eq['estado']) ?></td>
            <td><?= e(date('d/m/Y', strtotime($eq['fecha_alta']))) ?></td>
            <td><?= e($eq['observaciones']) ?></td>
            <td class="acciones">
                <a class="boton secundario" href="/editar.php?id=<?= (int)$eq['id'] ?>">Modificar</a>
                <form method="post" action="/eliminar.php" onsubmit="return confirm('¿Eliminar <?= e($eq['codigo']) ?>?')">
                    <input type="hidden" name="id" value="<?= (int)$eq['id'] ?>">
                    <button class="boton peligro">Eliminar</button>
                </form>
            </td>
        </tr>
    <?php endforeach; ?>
</table>
<p><?= count($equipos) ?> equipo(s) registrado(s).</p>
<?php pie();
