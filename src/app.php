<?php
const APP_VERSION = '1.1.0';
const TIPOS = ['PC', 'Notebook', 'Servidor', 'Impresora', 'Switch', 'Router', 'Monitor', 'Otro'];
const ESTADOS = ['Operativo', 'En reparación', 'Fuera de servicio', 'Baja'];
const CAMPOS = ['codigo', 'tipo', 'marca', 'modelo', 'numero_serie', 'ubicacion', 'responsable', 'estado', 'fecha_alta', 'observaciones'];

function db(): PDO
{
    static $pdo = null;
    if ($pdo === null) {
        $c = (require '/etc/miproyecto/config.php')['db'];
        $pdo = new PDO("mysql:unix_socket={$c['socket']};dbname={$c['name']};charset=utf8mb4", $c['user'], $c['pass'], [
            PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
            PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
        ]);
    }
    return $pdo;
}

function e($valor): string
{
    return htmlspecialchars((string)$valor, ENT_QUOTES, 'UTF-8');
}

function ir_al_inicio(): never
{
    header('Location: /');
    exit;
}

function datos_del_formulario(): array
{
    $datos = [];
    foreach (CAMPOS as $campo) {
        $valor = trim($_POST[$campo] ?? '');
        $datos[$campo] = $valor === '' ? null : $valor;
    }
    $datos['codigo'] = strtoupper((string)$datos['codigo']);
    return $datos;
}

function guardar(string $sql, array $datos): ?string
{
    try {
        db()->prepare($sql)->execute($datos);
        ir_al_inicio();
    } catch (PDOException $ex) {
        if ($ex->getCode() === '23000') {
            return 'Ya existe un equipo con ese código o faltan datos obligatorios.';
        }
        throw $ex;
    }
}

function cabecera(string $titulo): void
{
    ?>
<!doctype html>
<html lang="es">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title><?= e($titulo) ?> · Inventario de Equipos</title>
    <link rel="stylesheet" href="/assets/estilos.css">
</head>
<body>
<header>
    <strong>Inventario de Equipos</strong>
    <nav>
        <a href="/">Inventario</a>
        <a href="/crear.php">Registrar equipo</a>
        <a href="/estado.php">Estado del servidor</a>
    </nav>
</header>
<main>
<?php
}

function pie(): void
{
    ?>
</main>
<footer>Inventario de Equipos · versión <?= APP_VERSION ?> · servidor <?= e(gethostname()) ?></footer>
</body>
</html>
<?php
}

function opciones(array $lista, ?string $elegido): void
{
    foreach ($lista as $op) {
        echo '<option' . ($op === $elegido ? ' selected' : '') . '>' . e($op) . '</option>';
    }
}

function formulario(array $d, string $boton): void
{
    ?>
<form method="post">
    <label>Código <input name="codigo" value="<?= e($d['codigo'] ?? '') ?>" required maxlength="20"></label>
    <label>Tipo <select name="tipo" required><?php opciones(TIPOS, $d['tipo'] ?? null); ?></select></label>
    <label>Marca <input name="marca" value="<?= e($d['marca'] ?? '') ?>" required maxlength="60"></label>
    <label>Modelo <input name="modelo" value="<?= e($d['modelo'] ?? '') ?>" required maxlength="80"></label>
    <label>Número de serie <input name="numero_serie" value="<?= e($d['numero_serie'] ?? '') ?>" maxlength="80"></label>
    <label>Ubicación <input name="ubicacion" value="<?= e($d['ubicacion'] ?? '') ?>" required maxlength="80"></label>
    <label>Responsable <input name="responsable" value="<?= e($d['responsable'] ?? '') ?>" maxlength="80"></label>
    <label>Estado <select name="estado" required><?php opciones(ESTADOS, $d['estado'] ?? null); ?></select></label>
    <label>Fecha de alta <input type="date" name="fecha_alta" value="<?= e($d['fecha_alta'] ?? date('Y-m-d')) ?>" required></label>
    <label>Observaciones <textarea name="observaciones" maxlength="1000"><?= e($d['observaciones'] ?? '') ?></textarea></label>
    <div>
        <a class="boton secundario" href="/">Cancelar</a>
        <button class="boton"><?= e($boton) ?></button>
    </div>
</form>
<?php
}
