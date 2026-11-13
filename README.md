## Estructura

```
miproyecto/
├── public/            ← DocumentRoot de Apache (lo único accesible desde la web)
│   ├── index.php  crear.php  editar.php  eliminar.php  estado.php
│   └── assets/estilos.css
├── src/app.php        ← conexión a la base de datos, plantilla y formulario
├── sql/schema.sql     ← tabla de equipos
├── scripts/           ← deploy.sh · backup.sh · restore.sh
└── setup/             ← instalación del servidor, un script por parte del práctico
```

Las credenciales de la base de datos están en `/etc/miproyecto/config.php` y las de Backblaze en
`/root/.config/rclone/rclone.conf`, fuera del repositorio.

## Instalación (en el servidor)

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

Demostración de la Parte 2:

```bash
sudo bash setup/02_demo_gestion_usuarios.sh       # crear, modificar, bloquear y eliminar un usuario
sudo bash setup/02_verificar_permisos.sh          # a qué puede acceder cada usuario
```

Operación diaria:

```bash
sudo deploy.sh                          # actualiza la app desde la rama main de GitHub
sudo backup.sh                          # respaldo manual (local + Backblaze B2)
sudo restore.sh --listar --nube         # respaldos disponibles en la nube
sudo restore.sh --nube ultimo           # recupera archivos y base desde la nube
```
