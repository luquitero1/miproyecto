# Inventario de Equipos — Centro de Cómputos

Aplicación web en **PHP + MariaDB** para registrar los equipos informáticos de un
centro de cómputos. Se publica con **Apache** en `http://miproyecto.com` y es parte del
práctico final de *Administración de Sistemas* (Debian/Ubuntu, sin Docker).

| Funcionalidad | Página |
|---|---|
| Inventario con resumen por estado, búsqueda y filtros | `/` |
| Registrar un equipo (formulario con validación) | `/crear.php` |
| Modificar un equipo | `/editar.php?id=N` |
| Eliminar un equipo (con confirmación) | botón *Eliminar* |
| Verificación de Apache + PHP + base de datos | `/estado.php` |

## Estructura

```
miproyecto/
├── public/            ← DocumentRoot de Apache (lo único accesible desde la web)
│   ├── index.php  crear.php  editar.php  eliminar.php  estado.php
│   └── assets/estilos.css
├── src/               ← lógica: conexión PDO, validación, plantillas
├── sql/               ← schema.sql (tablas) y datos_ejemplo.sql
├── config/            ← config.example.php (las credenciales reales NO están en Git)
├── scripts/           ← deploy.sh · backup.sh · restore.sh
├── setup/             ← instalación del servidor, un script por parte del práctico
└── docs/GUIA.md       ← guía paso a paso y guion de demostración
```

## Instalación rápida (en el servidor)

```bash
sudo bash setup/01_sistema.sh centro-computos     # Parte 1: sistema, SSH, directorios
sudo bash setup/02_usuarios_grupos.sh             # Parte 2: usuarios, grupos, permisos
sudo bash setup/03_servicios.sh                   # Parte 3: Apache, PHP, MariaDB, Git
sudo bash setup/04_clonar_repositorio.sh https://github.com/<USUARIO>/miproyecto.git
sudo bash setup/05_base_datos.sh                  # Parte 4: base de datos y credenciales
sudo bash setup/06_apache_vhost.sh                # Parte 5: VirtualHost + /etc/hosts
sudo bash setup/07_respaldos_cron.sh              # Parte 7: backup.sh + crontab
sudo bash setup/08_backblaze_rclone.sh            # Parte 8: Backblaze B2 + Rclone
```

Operación diaria:

```bash
sudo deploy.sh                          # actualiza la app desde la rama main de GitHub
sudo backup.sh                          # respaldo manual (local + Backblaze B2)
sudo restore.sh --listar --nube         # respaldos disponibles en la nube
sudo restore.sh --nube ultimo           # recupera archivos y base desde la nube
```

Ver **[docs/GUIA.md](docs/GUIA.md)** para el detalle de cada parte.

## Seguridad

- Las credenciales **no se publican**: la app lee `/etc/miproyecto/config.php`
  (640 `root:www-data`, generado con contraseña aleatoria) y las claves de Backblaze
  están en `/root/.config/rclone/rclone.conf` (600). `.gitignore` excluye configuraciones,
  respaldos y logs.
- Consultas preparadas (PDO), escape de HTML, token CSRF en todos los formularios
  y eliminación sólo por POST.
- El usuario de base de datos de la app sólo tiene `SELECT, INSERT, UPDATE, DELETE`.
- Apache sólo expone `public/`; `.git`, `src/`, `sql/` y `scripts/` no son accesibles.
