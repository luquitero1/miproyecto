<?php
require __DIR__ . '/../src/app.php';

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    db()->prepare('DELETE FROM equipos WHERE id = ?')->execute([(int)($_POST['id'] ?? 0)]);
}
ir_al_inicio();
