<?php
/** Baja definitiva de un equipo. Sólo acepta POST con token CSRF. */
declare(strict_types=1);
require __DIR__ . '/../src/bootstrap.php';

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405);
    header('Allow: POST');
    exit('Método no permitido.');
}
csrf_verificar();

$id = filter_input(INPUT_POST, 'id', FILTER_VALIDATE_INT, ['options' => ['min_range' => 1]]);
if (!$id) {
    flash('Equipo no especificado.', 'error');
    redirigir('/');
}

$stmt = db()->prepare('SELECT codigo FROM equipos WHERE id = :id');
$stmt->execute(['id' => $id]);
$codigo = $stmt->fetchColumn();

if ($codigo === false) {
    flash('El equipo ya no existe.', 'error');
} else {
    db()->prepare('DELETE FROM equipos WHERE id = :id')->execute(['id' => $id]);
    flash("Equipo $codigo eliminado.");
}
redirigir('/');
