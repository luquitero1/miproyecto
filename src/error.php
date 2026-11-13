<?php
/** Página de error genérica. Variables disponibles: $ex (Throwable), $debug (bool). */
?>
<!doctype html>
<html lang="es">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>Error · <?= htmlspecialchars(APP_NOMBRE) ?></title>
    <link rel="stylesheet" href="/assets/estilos.css">
</head>
<body>
<main class="contenedor">
    <div class="tarjeta error-pagina">
        <h1>Ocurrió un error</h1>
        <p>La aplicación no pudo completar la operación. El detalle quedó registrado en el log de Apache
            (<code>/var/log/apache2/miproyecto_error.log</code>).</p>
        <?php if (!empty($debug)): ?>
            <pre><?= htmlspecialchars($ex::class . ': ' . $ex->getMessage()) ?></pre>
        <?php endif; ?>
        <p><a class="boton" href="/">Volver al inicio</a></p>
    </div>
</main>
</body>
</html>
