<?php
/** Formulario reutilizado para registrar y modificar equipos. */
declare(strict_types=1);

function formulario_equipo(array $d, array $err, string $accion, string $textoBoton): void
{
    $campoTexto = function (string $nombre, string $etiqueta, bool $obligatorio = false, string $extra = '') use ($d, $err): void {
        ?>
        <div class="campo <?= isset($err[$nombre]) ? 'campo--error' : '' ?>">
            <label for="<?= e($nombre) ?>"><?= e($etiqueta) ?><?= $obligatorio ? ' <span class="req">*</span>' : '' ?></label>
            <input type="text" id="<?= e($nombre) ?>" name="<?= e($nombre) ?>" value="<?= e($d[$nombre] ?? '') ?>"
                <?= $obligatorio ? 'required' : '' ?> <?= $extra ?>>
            <?php if (isset($err[$nombre])): ?><small class="error"><?= e($err[$nombre]) ?></small><?php endif; ?>
        </div>
        <?php
    };
    $campoLista = function (string $nombre, string $etiqueta, array $opciones) use ($d, $err): void {
        ?>
        <div class="campo <?= isset($err[$nombre]) ? 'campo--error' : '' ?>">
            <label for="<?= e($nombre) ?>"><?= e($etiqueta) ?> <span class="req">*</span></label>
            <select id="<?= e($nombre) ?>" name="<?= e($nombre) ?>" required>
                <option value="">— Seleccionar —</option>
                <?php foreach ($opciones as $op): ?>
                    <option value="<?= e($op) ?>" <?= ($d[$nombre] ?? '') === $op ? 'selected' : '' ?>><?= e($op) ?></option>
                <?php endforeach; ?>
            </select>
            <?php if (isset($err[$nombre])): ?><small class="error"><?= e($err[$nombre]) ?></small><?php endif; ?>
        </div>
        <?php
    };
    ?>
    <form method="post" action="<?= e($accion) ?>" class="tarjeta formulario" novalidate>
        <?= csrf_campo() ?>
        <div class="rejilla">
            <?php $campoTexto('codigo', 'Código de inventario', true, 'maxlength="20" placeholder="PC-001" autocomplete="off"'); ?>
            <?php $campoLista('tipo', 'Tipo de equipo', TIPOS_EQUIPO); ?>
            <?php $campoTexto('marca', 'Marca', true, 'maxlength="60"'); ?>
            <?php $campoTexto('modelo', 'Modelo', true, 'maxlength="80"'); ?>
            <?php $campoTexto('numero_serie', 'Número de serie', false, 'maxlength="80"'); ?>
            <?php $campoTexto('ubicacion', 'Ubicación', true, 'maxlength="80" placeholder="Sala de servidores"'); ?>
            <?php $campoTexto('responsable', 'Responsable', false, 'maxlength="80"'); ?>
            <?php $campoLista('estado', 'Estado', ESTADOS_EQUIPO); ?>
            <div class="campo <?= isset($err['fecha_alta']) ? 'campo--error' : '' ?>">
                <label for="fecha_alta">Fecha de alta <span class="req">*</span></label>
                <input type="date" id="fecha_alta" name="fecha_alta" value="<?= e($d['fecha_alta'] ?? date('Y-m-d')) ?>" required>
                <?php if (isset($err['fecha_alta'])): ?><small class="error"><?= e($err['fecha_alta']) ?></small><?php endif; ?>
            </div>
            <div class="campo campo--ancho <?= isset($err['observaciones']) ? 'campo--error' : '' ?>">
                <label for="observaciones">Observaciones</label>
                <textarea id="observaciones" name="observaciones" rows="3" maxlength="1000"><?= e($d['observaciones'] ?? '') ?></textarea>
                <?php if (isset($err['observaciones'])): ?><small class="error"><?= e($err['observaciones']) ?></small><?php endif; ?>
            </div>
        </div>
        <div class="acciones">
            <a class="boton boton--secundario" href="/">Cancelar</a>
            <button type="submit" class="boton"><?= e($textoBoton) ?></button>
        </div>
    </form>
    <?php
}
