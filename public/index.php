<?php
/** Página principal: resumen e inventario de equipos con búsqueda y filtros. */
declare(strict_types=1);
require __DIR__ . '/../src/bootstrap.php';

$q      = trim((string)($_GET['q'] ?? ''));
$estado = (string)($_GET['estado'] ?? '');
$tipo   = (string)($_GET['tipo'] ?? '');

$where = [];
$params = [];
if ($q !== '') {
    $where[] = '(codigo LIKE :q1 OR marca LIKE :q2 OR modelo LIKE :q3 OR ubicacion LIKE :q4 OR responsable LIKE :q5 OR numero_serie LIKE :q6)';
    for ($i = 1; $i <= 6; $i++) {
        $params["q$i"] = '%' . $q . '%';
    }
}
if (in_array($estado, ESTADOS_EQUIPO, true)) {
    $where[] = 'estado = :estado';
    $params['estado'] = $estado;
}
if (in_array($tipo, TIPOS_EQUIPO, true)) {
    $where[] = 'tipo = :tipo';
    $params['tipo'] = $tipo;
}
$sql = 'SELECT * FROM equipos' . ($where ? ' WHERE ' . implode(' AND ', $where) : '') . ' ORDER BY codigo';
$stmt = db()->prepare($sql);
$stmt->execute($params);
$equipos = $stmt->fetchAll();

$resumen = db()->query('SELECT estado, COUNT(*) AS total FROM equipos GROUP BY estado')->fetchAll(PDO::FETCH_KEY_PAIR);
$total = array_sum($resumen);
$filtrando = $where !== [];

cabecera('Inventario', 'inicio');
?>
<section class="encabezado">
    <div>
        <h1>Inventario de equipos</h1>
        <p class="sutil">Registro de los equipos informáticos del centro de cómputos.</p>
    </div>
    <a class="boton" href="/crear.php">+ Registrar equipo</a>
</section>

<div class="aviso aviso--ok" role="note">
    Versión 1.1.0: actualizada desde GitHub mediante <code>deploy.sh</code>.
</div>

<section class="resumen">
    <div class="dato"><span class="dato__valor"><?= $total ?></span><span class="dato__etiqueta">Equipos registrados</span></div>
    <?php foreach (ESTADOS_EQUIPO as $est): ?>
        <a class="dato dato--<?= clase_estado($est) ?>"
           href="/?estado=<?= urlencode($est) ?>">
            <span class="dato__valor"><?= (int)($resumen[$est] ?? 0) ?></span>
            <span class="dato__etiqueta"><?= e($est) ?></span>
        </a>
    <?php endforeach; ?>
</section>

<form class="filtros tarjeta" method="get" action="/">
    <input type="search" name="q" value="<?= e($q) ?>" placeholder="Buscar por código, marca, modelo, ubicación…" aria-label="Buscar">
    <select name="tipo" aria-label="Tipo">
        <option value="">Todos los tipos</option>
        <?php foreach (TIPOS_EQUIPO as $t): ?>
            <option <?= $t === $tipo ? 'selected' : '' ?>><?= e($t) ?></option>
        <?php endforeach; ?>
    </select>
    <select name="estado" aria-label="Estado">
        <option value="">Todos los estados</option>
        <?php foreach (ESTADOS_EQUIPO as $est): ?>
            <option <?= $est === $estado ? 'selected' : '' ?>><?= e($est) ?></option>
        <?php endforeach; ?>
    </select>
    <button class="boton" type="submit">Filtrar</button>
    <?php if ($filtrando): ?><a class="boton boton--secundario" href="/">Limpiar</a><?php endif; ?>
</form>

<?php if (!$equipos): ?>
    <div class="tarjeta vacio">
        <?php if ($filtrando): ?>
            No hay equipos que coincidan con la búsqueda.
        <?php else: ?>
            Todavía no hay equipos registrados. <a href="/crear.php">Registrá el primero</a>.
        <?php endif; ?>
    </div>
<?php else: ?>
    <div class="tabla-envoltura tarjeta">
        <table class="tabla">
            <thead>
            <tr>
                <th>Código</th>
                <th>Tipo</th>
                <th>Marca / Modelo</th>
                <th>Ubicación</th>
                <th>Responsable</th>
                <th>Estado</th>
                <th>Alta</th>
                <th class="col-acciones">Acciones</th>
            </tr>
            </thead>
            <tbody>
            <?php foreach ($equipos as $eq): ?>
                <tr>
                    <td><strong><?= e($eq['codigo']) ?></strong>
                        <?php if ($eq['numero_serie']): ?><br><small class="sutil">S/N <?= e($eq['numero_serie']) ?></small><?php endif; ?>
                    </td>
                    <td><?= e($eq['tipo']) ?></td>
                    <td><?= e($eq['marca']) ?> <span class="sutil"><?= e($eq['modelo']) ?></span></td>
                    <td><?= e($eq['ubicacion']) ?></td>
                    <td><?= e($eq['responsable'] ?? '—') ?></td>
                    <td><span class="etiqueta etiqueta--<?= clase_estado($eq['estado']) ?>"><?= e($eq['estado']) ?></span></td>
                    <td><?= e(date('d/m/Y', strtotime($eq['fecha_alta']))) ?></td>
                    <td class="col-acciones">
                        <a class="boton boton--chico boton--secundario" href="/editar.php?id=<?= (int)$eq['id'] ?>">Modificar</a>
                        <form method="post" action="/eliminar.php" class="en-linea"
                              onsubmit="return confirm('¿Eliminar el equipo <?= e($eq['codigo']) ?>? Esta acción no se puede deshacer.');">
                            <?= csrf_campo() ?>
                            <input type="hidden" name="id" value="<?= (int)$eq['id'] ?>">
                            <button class="boton boton--chico boton--peligro" type="submit">Eliminar</button>
                        </form>
                    </td>
                </tr>
            <?php endforeach; ?>
            </tbody>
        </table>
    </div>
    <p class="sutil"><?= count($equipos) ?> de <?= $total ?> equipos mostrados.</p>
<?php endif; ?>
<?php pie();
