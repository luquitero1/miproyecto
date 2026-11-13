<?php
/**
 * Inventario de Equipos — Centro de Cómputos
 * Archivo de arranque: configuración, conexión a la base de datos y utilidades.
 */
declare(strict_types=1);

const APP_NOMBRE  = 'Inventario de Equipos';
const APP_VERSION = '1.0.0';
const APP_ROOT    = __DIR__ . '/..';

/** Tipos y estados válidos para un equipo. */
const TIPOS_EQUIPO = ['PC', 'Notebook', 'Servidor', 'Impresora', 'Switch', 'Router', 'Monitor', 'Otro'];
const ESTADOS_EQUIPO = ['Operativo', 'En reparación', 'Fuera de servicio', 'Baja'];

/** Zona horaria: la del sistema operativo (PHP usa UTC por defecto). */
(function (): void {
    $zona = 'UTC';
    $enlace = @readlink('/etc/localtime');
    if ($enlace && preg_match('#zoneinfo/(.+)$#', $enlace, $m) && in_array($m[1], timezone_identifiers_list(), true)) {
        $zona = $m[1];
    }
    date_default_timezone_set($zona);
})();

session_start([
    'cookie_httponly' => true,
    'cookie_samesite' => 'Lax',
    'use_strict_mode' => true,
]);

/**
 * Carga la configuración. Las credenciales NUNCA se guardan en el repositorio:
 *   1. Variable de entorno MIPROYECTO_CONFIG (ruta a un archivo)
 *   2. /etc/miproyecto/config.php   (servidor de producción)
 *   3. config/config.php            (desarrollo local, ignorado por Git)
 */
function config(): array
{
    static $config = null;
    if ($config !== null) {
        return $config;
    }
    $candidatos = array_filter([
        getenv('MIPROYECTO_CONFIG') ?: null,
        '/etc/miproyecto/config.php',
        APP_ROOT . '/config/config.php',
    ]);
    foreach ($candidatos as $archivo) {
        if (is_readable($archivo)) {
            $config = require $archivo;
            return $config;
        }
    }
    throw new RuntimeException('No se encontró el archivo de configuración (ver config/config.example.php).');
}

/** Devuelve la conexión PDO (única por petición). */
function db(): PDO
{
    static $pdo = null;
    if ($pdo instanceof PDO) {
        return $pdo;
    }
    $c = config()['db'];
    if (!empty($c['socket']) && file_exists($c['socket'])) {
        $dsn = sprintf('mysql:unix_socket=%s;dbname=%s;charset=utf8mb4', $c['socket'], $c['name']);
    } else {
        $dsn = sprintf('mysql:host=%s;port=%d;dbname=%s;charset=utf8mb4', $c['host'], (int)($c['port'] ?? 3306), $c['name']);
    }
    $pdo = new PDO($dsn, $c['user'], $c['pass'], [
        PDO::ATTR_ERRMODE            => PDO::ERRMODE_EXCEPTION,
        PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
        PDO::ATTR_EMULATE_PREPARES   => false,
    ]);
    return $pdo;
}

/** Escapa texto para mostrarlo en HTML (previene XSS). */
function e(mixed $valor): string
{
    return htmlspecialchars((string)($valor ?? ''), ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8');
}

/** Token CSRF para los formularios. */
function csrf_token(): string
{
    if (empty($_SESSION['csrf'])) {
        $_SESSION['csrf'] = bin2hex(random_bytes(32));
    }
    return $_SESSION['csrf'];
}

function csrf_campo(): string
{
    return '<input type="hidden" name="csrf" value="' . e(csrf_token()) . '">';
}

function csrf_verificar(): void
{
    $enviado = $_POST['csrf'] ?? '';
    if (!is_string($enviado) || !hash_equals(csrf_token(), $enviado)) {
        http_response_code(400);
        exit('Solicitud inválida (token CSRF). Volvé a cargar la página e intentá de nuevo.');
    }
}

/** Mensajes que sobreviven a una redirección. */
function flash(string $mensaje, string $tipo = 'ok'): void
{
    $_SESSION['flash'] = ['mensaje' => $mensaje, 'tipo' => $tipo];
}

function flash_obtener(): ?array
{
    $f = $_SESSION['flash'] ?? null;
    unset($_SESSION['flash']);
    return $f;
}

function redirigir(string $url): never
{
    header('Location: ' . $url);
    exit;
}

/**
 * Valida y normaliza los datos de un equipo enviados por formulario.
 * @return array{0: array, 1: array} [datos, errores]
 */
function validar_equipo(array $in): array
{
    $t = fn(string $k): string => trim((string)($in[$k] ?? ''));
    $d = [
        'codigo'        => strtoupper($t('codigo')),
        'tipo'          => $t('tipo'),
        'marca'         => $t('marca'),
        'modelo'        => $t('modelo'),
        'numero_serie'  => $t('numero_serie'),
        'ubicacion'     => $t('ubicacion'),
        'responsable'   => $t('responsable'),
        'estado'        => $t('estado'),
        'fecha_alta'    => $t('fecha_alta'),
        'observaciones' => $t('observaciones'),
    ];
    $err = [];

    if (!preg_match('/^[A-Z0-9-]{3,20}$/', $d['codigo'])) {
        $err['codigo'] = 'Usá entre 3 y 20 caracteres: letras, números o guiones (ej. PC-001).';
    }
    if (!in_array($d['tipo'], TIPOS_EQUIPO, true)) {
        $err['tipo'] = 'Elegí un tipo de la lista.';
    }
    foreach (['marca' => 60, 'modelo' => 80, 'ubicacion' => 80] as $campo => $max) {
        if ($d[$campo] === '') {
            $err[$campo] = 'Este campo es obligatorio.';
        } elseif (mb_strlen($d[$campo]) > $max) {
            $err[$campo] = "Máximo $max caracteres.";
        }
    }
    foreach (['numero_serie' => 80, 'responsable' => 80, 'observaciones' => 1000] as $campo => $max) {
        if (mb_strlen($d[$campo]) > $max) {
            $err[$campo] = "Máximo $max caracteres.";
        }
    }
    if (!in_array($d['estado'], ESTADOS_EQUIPO, true)) {
        $err['estado'] = 'Elegí un estado de la lista.';
    }
    $fecha = DateTime::createFromFormat('!Y-m-d', $d['fecha_alta']);
    if (!$fecha || $fecha->format('Y-m-d') !== $d['fecha_alta']) {
        $err['fecha_alta'] = 'Ingresá una fecha válida.';
    }

    // Los campos opcionales vacíos se guardan como NULL.
    foreach (['numero_serie', 'responsable', 'observaciones'] as $campo) {
        if ($d[$campo] === '') {
            $d[$campo] = null;
        }
    }
    return [$d, $err];
}

/** Clase CSS asociada a cada estado. */
function clase_estado(string $estado): string
{
    return match ($estado) {
        'Operativo'         => 'operativo',
        'En reparación'     => 'reparacion',
        'Fuera de servicio' => 'fuera',
        'Baja'              => 'baja',
        default             => 'otro',
    };
}

/** ¿El error de PDO corresponde a una clave duplicada? */
function es_duplicado(PDOException $ex): bool
{
    return ($ex->errorInfo[1] ?? null) === 1062;
}

/** Commit de Git desplegado actualmente (se muestra en el pie de página). */
function commit_desplegado(): ?string
{
    $git = APP_ROOT . '/.git';
    $head = @file_get_contents($git . '/HEAD');
    if ($head === false) {
        return null;
    }
    $head = trim($head);
    if (!str_starts_with($head, 'ref: ')) {
        return substr($head, 0, 7);
    }
    $ref = substr($head, 5);
    $hash = @file_get_contents($git . '/' . $ref);
    if ($hash === false) {
        $packed = @file($git . '/packed-refs', FILE_IGNORE_NEW_LINES) ?: [];
        foreach ($packed as $linea) {
            if (str_ends_with($linea, ' ' . $ref)) {
                $hash = strtok($linea, ' ');
                break;
            }
        }
    }
    return $hash ? substr(trim($hash), 0, 7) : null;
}

/** Manejo centralizado de errores: se registran en el log de Apache, no se muestran al usuario. */
set_exception_handler(function (Throwable $ex): void {
    error_log('[miproyecto] ' . $ex::class . ': ' . $ex->getMessage() . ' en ' . $ex->getFile() . ':' . $ex->getLine());
    http_response_code(500);
    $debug = false;
    try {
        $debug = (bool)(config()['debug'] ?? false);
    } catch (Throwable) {
    }
    require __DIR__ . '/error.php';
});

require __DIR__ . '/layout.php';
