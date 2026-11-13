<?php
/** Plantilla común: cabecera, navegación y pie de página. */
declare(strict_types=1);

function cabecera(string $titulo, string $activo = ''): void
{
    $nav = [
        'inicio' => ['/', 'Inventario'],
        'nuevo'  => ['/crear.php', 'Registrar equipo'],
        'estado' => ['/estado.php', 'Estado del servidor'],
    ];
    $flash = flash_obtener();
    ?>
<!doctype html>
<html lang="es">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title><?= e($titulo) ?> · <?= e(APP_NOMBRE) ?></title>
    <link rel="stylesheet" href="/assets/estilos.css">
</head>
<body>
<header class="barra">
    <div class="contenedor barra__fila">
        <a class="marca" href="/">
            <span class="marca__logo" aria-hidden="true">▦</span>
            <span><?= e(APP_NOMBRE) ?><small>Centro de Cómputos</small></span>
        </a>
        <nav class="nav">
            <?php foreach ($nav as $clave => [$url, $texto]): ?>
                <a href="<?= e($url) ?>" class="<?= $clave === $activo ? 'activo' : '' ?>"><?= e($texto) ?></a>
            <?php endforeach; ?>
        </nav>
    </div>
</header>
<main class="contenedor">
    <?php if ($flash): ?>
        <div class="aviso aviso--<?= e($flash['tipo']) ?>" role="status"><?= e($flash['mensaje']) ?></div>
    <?php endif; ?>
<?php
}

function pie(): void
{
    $commit = commit_desplegado();
    ?>
</main>
<footer class="pie">
    <div class="contenedor">
        <?= e(APP_NOMBRE) ?> · versión <?= e(APP_VERSION) ?>
        <?php if ($commit): ?> · commit <code><?= e($commit) ?></code><?php endif; ?>
        · servidor <code><?= e(gethostname() ?: 'desconocido') ?></code>
    </div>
</footer>
</body>
</html>
<?php
}
