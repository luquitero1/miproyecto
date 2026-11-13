# Guía de implementación y demostración

**Práctico final — Administración de Sistemas**
Centro de cómputos Linux: Apache + PHP + MariaDB, GitHub, respaldos locales y en Backblaze B2.

Todos los comandos se ejecutan en el servidor (Debian 13), desde la carpeta del
proyecto (`cd ~/Sistemas/miproyecto`), salvo que se indique otra cosa.

---

## 0. Antes de empezar

### Orden de ejecución

| Paso | Comando | Parte del práctico |
|---|---|---|
| 1 | `sudo bash setup/01_sistema.sh centro-computos` | 1 — Sistema, red, SSH, directorios |
| 2 | `sudo bash setup/02_usuarios_grupos.sh` | 2 — Usuarios, grupos y permisos |
| 3 | `sudo bash setup/03_servicios.sh` | 3 — Apache, PHP, MariaDB, Git, SSH |
| 4 | Crear el repositorio en GitHub y hacer `git push` ([§6.1](#61-crear-el-repositorio-y-subir-el-código)) | 6 — GitHub |
| 5 | `sudo bash setup/04_clonar_repositorio.sh https://github.com/<USUARIO>/miproyecto.git` | 5/6 — Clonar en `/var/www` |
| 6 | `sudo bash setup/05_base_datos.sh` | 4 — Base de datos |
| 7 | `sudo bash setup/06_apache_vhost.sh` | 5 — VirtualHost y dominio local |
| 8 | Cambio visible + `git push` + `sudo deploy.sh` | 6 — Despliegue |
| 9 | `sudo bash setup/07_respaldos_cron.sh` | 7 — Respaldos locales y crontab |
| 10 | Crear bucket y clave en Backblaze, luego `sudo bash setup/08_backblaze_rclone.sh` | 8 — Respaldos en la nube |

Todos los scripts se pueden volver a ejecutar sin romper nada (son idempotentes).

### Ubicaciones importantes

| Qué | Dónde |
|---|---|
| Código de desarrollo (se sube a GitHub) | `~/Sistemas/miproyecto` |
| Aplicación publicada (clon de GitHub) | `/var/www/miproyecto` — DocumentRoot: `/var/www/miproyecto/public` |
| Credenciales de la base de datos | `/etc/miproyecto/config.php` (640 `root:www-data`) |
| Configuración de respaldos | `/etc/miproyecto/backup.conf` |
| VirtualHost | `/etc/apache2/sites-available/miproyecto.com.conf` |
| Scripts instalados | `/usr/local/bin/deploy.sh`, `backup.sh`, `restore.sh` |
| Respaldos locales | `/srv/respaldos/local/` |
| Registros | `/srv/respaldos/logs/backup.log`, `rclone.log`, `restore.log`, `cron.log` · `/var/log/miproyecto/deploy.log` |
| Credenciales de Backblaze | `/root/.config/rclone/rclone.conf` (600 `root:root`) |
| Logs de Apache | `/var/log/apache2/miproyecto_error.log`, `miproyecto_access.log` |

### ⚠ Docker

El práctico **no permite Docker**, y en esta máquina hay contenedores
(`aurora_db`, `minute_app_db`) que además ocupan el puerto 3306 de MariaDB.
Antes de instalar y antes de la presentación:

```bash
sudo docker stop $(sudo docker ps -q)            # detener todos los contenedores
sudo systemctl disable --now docker docker.socket  # (opcional) que no arranque Docker
```

Si el puerto 3306 sigue ocupado, `03_servicios.sh` configura MariaDB en el 3307 automáticamente
(la app usa el socket Unix, así que no se ve afectada). Si después liberás el 3306, borrá
`/etc/mysql/mariadb.conf.d/60-centro-computos.cnf` y ejecutá `sudo systemctl restart mariadb`.

### Máquina virtual

La VM usa la red **NAT** de VirtualBox (IP 10.0.2.15): el equipo anfitrión no llega a esa IP.
Lo más simple es demostrar todo **con el navegador dentro de la VM** (`http://miproyecto.com`).
Si se quiere acceder desde el anfitrión, cambiar el adaptador a **Adaptador puente** o
**Solo anfitrión** y agregar la IP de la VM al archivo hosts del anfitrión (ver Parte 5).

---

## Parte 1 — Implementación del centro de cómputos

```bash
sudo bash setup/01_sistema.sh centro-computos
```

| Requisito | Qué hace el script |
|---|---|
| Nombre del equipo | `hostnamectl set-hostname centro-computos` y actualiza la línea `127.0.1.1` de `/etc/hosts` |
| Red y conectividad | `ip -brief address`, `ip route`, `ping 8.8.8.8`, resolución DNS |
| Actualizar el sistema | `apt-get update`, `apt-get full-upgrade`, `apt-get autoremove` |
| Herramientas | curl, wget, vim, htop, tree, net-tools, dnsutils, rsync, acl, lsof, sysstat, git, cron… |
| SSH | instala `openssh-server`, configura `/etc/ssh/sshd_config.d/10-centro-computos.conf` (sin login de root, máx. 3 intentos, sólo grupos autorizados, banner), valida con `sshd -t` y lo habilita |
| Directorios | `/srv/administracion`, `/srv/proyectos`, `/srv/compartido`, `/srv/respaldos/{local,logs,restauracion}`, `/var/log/miproyecto` |
| Estado y recursos | ejecuta `setup/info_sistema.sh` |

**Para mostrar al docente**

```bash
hostnamectl                         # nombre del equipo y sistema
ip -brief a ; ip r                  # interfaces, IP y puerta de enlace
ping -c 3 google.com                # conectividad + DNS
apt list --upgradable               # sistema actualizado (lista vacía)
systemctl status ssh                # SSH activo
ssh ana@localhost                   # ingreso por SSH con un usuario del sistema
ssh root@localhost                  # rechazado: PermitRootLogin no
tree -d -L 2 /srv                   # estructura de directorios
free -h ; df -h ; uptime ; htop     # recursos
bash setup/info_sistema.sh          # resumen completo
```

---

## Parte 2 — Usuarios, grupos y permisos

```bash
sudo bash setup/02_usuarios_grupos.sh          # pide la contraseña inicial
sudo bash setup/02_verificar_permisos.sh       # matriz de accesos real
sudo bash setup/02_demo_gestion_usuarios.sh    # crear / modificar / bloquear / eliminar
```

### Usuarios y grupos

| Grupo | Usuarios | Responsabilidad | Privilegios de sudo |
|---|---|---|---|
| `administradores` | ana, bruno (+ tu usuario) | configuración del servidor | todos (grupo `sudo`) |
| `desarrolladores` | carla, diego | archivos de la aplicación | sólo `deploy.sh` |
| `respaldos` | elena, fabian | copias de seguridad | sólo `backup.sh` y `restore.sh` |

Cada usuario tiene su grupo personal y el grupo de su rol como secundario. Contraseñas con
vencimiento a 90 días (`chage -M 90 -W 7`). Con `--forzar-cambio` se obliga a cambiarla en el
primer ingreso. Las reglas de sudo están en `/etc/sudoers.d/centro-computos` (validadas con `visudo -c`).

### Directorios

| Directorio | Propietario | Permisos | Acceso |
|---|---|---|---|
| `/srv/administracion` | root:administradores | `2770` | privado de administradores |
| `/srv/proyectos` | root:desarrolladores | `2770` | privado de desarrolladores |
| `/srv/respaldos` (+ local, logs, restauracion) | root:respaldos | `2770` | privado de respaldos |
| `/srv/compartido` | root:administradores + ACL | `3770` | compartido por los 3 grupos; *sticky*: cada uno borra sólo lo suyo |
| `/home/<usuario>` | usuario | `0700` | privado de cada usuario |
| `/var/www/miproyecto` | root:desarrolladores | `2775` / `664` | desarrolladores escriben, Apache sólo lee |
| `/var/www/miproyecto/.git` | root:root | `755` | sólo root (no se pueden inyectar hooks) |
| `/etc/miproyecto/config.php` | root:www-data | `640` | sólo Apache lee las credenciales |

El bit **setgid** (`2xxx`) hace que los archivos nuevos hereden el grupo del directorio.

### Para mostrar al docente

```bash
getent group administradores desarrolladores respaldos
id carla
ls -ld /srv/* /home/*
getfacl /srv/compartido
sudo -l -U carla                           # qué puede ejecutar con sudo

su - carla                                 # entrar como desarrolladora
  ls /srv/proyectos                        # ✔ permitido
  ls /srv/administracion                   # ✘ Permiso denegado
  touch /var/www/miproyecto/public/x.txt   # ✔ puede editar la app
  rm /var/www/miproyecto/public/x.txt
  sudo backup.sh                           # ✘ no está autorizada
  exit

sudo bash setup/02_verificar_permisos.sh   # matriz completa con ✔/✘
```

### Crear, modificar, bloquear y eliminar (comandos manuales)

El script `02_demo_gestion_usuarios.sh` hace todo esto paso a paso con pausas. A mano:

```bash
sudo useradd -m -s /bin/bash -c "Usuario de prueba" -G desarrolladores practicante   # crear
sudo passwd practicante                                                             # contraseña
sudo usermod -c "Practicante de respaldos" -aG respaldos practicante                # modificar
sudo usermod -s /bin/sh practicante                                                 # cambiar shell
sudo chage -E 2026-12-31 practicante                                                # vencimiento
sudo usermod -L practicante        # bloquear  (passwd -S muestra "L")
sudo passwd -S practicante
sudo usermod -U practicante        # desbloquear
sudo userdel -r practicante        # eliminar (con su /home)
```

---

## Parte 3 — Instalación y administración de servicios

```bash
sudo bash setup/03_servicios.sh
```

Instala `apache2`, `php`, `libapache2-mod-php`, `php-mysql`, `php-mbstring`, `mariadb-server`,
`git` y `openssh-server` directamente en el sistema; habilita el inicio automático
(`systemctl enable --now`) de apache2, mariadb, ssh y cron; aplica el equivalente a
`mariadb-secure-installation` (sin usuarios anónimos, sin base `test`, root sólo local por socket)
y verifica que todo responda.

**Para mostrar al docente**

```bash
systemctl status apache2 mariadb ssh cron --no-pager
sudo systemctl stop apache2         # el sitio deja de responder
sudo systemctl start apache2
sudo systemctl restart mariadb
sudo systemctl reload apache2       # recarga la configuración sin cortar conexiones
systemctl is-enabled apache2 mariadb ssh cron

# Registros
sudo journalctl -u apache2 -n 20
sudo journalctl -u mariadb -n 20
sudo journalctl -p err -b           # errores desde el último arranque
sudo tail -n 20 /var/log/apache2/miproyecto_error.log

# Funcionamiento
php -v
sudo mariadb -e "SELECT VERSION();"
curl -I http://miproyecto.com
```

Y en el navegador: **http://miproyecto.com/estado.php** muestra versión de Apache, PHP,
MariaDB, el usuario con el que conecta la app y la cantidad de registros.

> Para generar y encontrar un error a propósito: `sudo systemctl stop mariadb`, abrir
> `http://miproyecto.com` (muestra "Ocurrió un error"), ver el detalle con
> `sudo tail -n 5 /var/log/apache2/miproyecto_error.log` y volver a iniciar MariaDB.

---

## Parte 4 — Aplicación web

**Temática: Inventario de equipos del centro de cómputos.**

| Requisito | Implementación |
|---|---|
| Página principal | `public/index.php`: resumen por estado, buscador y filtros por tipo/estado |
| Formulario de registro | `public/crear.php` (validación de todos los campos, código único) |
| Conexión a la base | `src/bootstrap.php` → PDO con socket Unix, credenciales en `/etc/miproyecto/config.php` |
| Almacenar datos | `INSERT` con consultas preparadas |
| Mostrar registros | tabla en la página principal |
| Modificar | `public/editar.php?id=N` |
| Eliminar | `public/eliminar.php` (POST + confirmación + token CSRF) |

Tabla `equipos` (ver `sql/schema.sql`): código, tipo, marca, modelo, número de serie,
ubicación, responsable, estado, fecha de alta, observaciones, fechas de creación/modificación.

```bash
sudo bash setup/05_base_datos.sh
```

Crea la base `miproyecto`, el usuario `miproyecto_app`@`localhost` con privilegios mínimos
(`SELECT, INSERT, UPDATE, DELETE`) y contraseña aleatoria, las tablas, 6 equipos de ejemplo
y el archivo `/etc/miproyecto/config.php`.

**Para mostrar al docente**: registrar un equipo en el navegador, modificarlo y eliminarlo; y
comprobar en la base:

```bash
sudo mariadb miproyecto -e "SELECT id, codigo, tipo, marca, estado FROM equipos;"
sudo mariadb -e "SHOW GRANTS FOR 'miproyecto_app'@'localhost';"
```

---

## Parte 5 — Apache y dominio local

```bash
sudo bash setup/04_clonar_repositorio.sh https://github.com/<USUARIO>/miproyecto.git   # (después de §6.1)
sudo bash setup/06_apache_vhost.sh
```

- La aplicación queda en `/var/www/miproyecto` y Apache sólo publica `public/`.
- VirtualHost `/etc/apache2/sites-available/miproyecto.com.conf` (`ServerName miproyecto.com`,
  `ServerAlias www.miproyecto.com`, sin listado de directorios, logs propios, cabeceras de seguridad).
- Se habilita con `a2ensite`, se valida con `apache2ctl configtest` y se recarga Apache.
- Agrega `127.0.0.1 miproyecto.com www.miproyecto.com` a `/etc/hosts`.

**Para mostrar al docente**

```bash
cat /etc/apache2/sites-available/miproyecto.com.conf
ls -l /etc/apache2/sites-enabled/
sudo apache2ctl -S                     # VirtualHosts activos
grep miproyecto /etc/hosts
getent hosts miproyecto.com            # 127.0.0.1
ls -la /var/www/miproyecto
```

Abrir **http://miproyecto.com** (escribir `http://` explícitamente).

**Acceso desde otro equipo** (anfitrión de la VM con red puente/solo anfitrión): agregar al
archivo hosts de ese equipo la IP de la VM (`hostname -I`):

```
192.168.x.x    miproyecto.com www.miproyecto.com
```

- Linux/macOS: `sudo nano /etc/hosts`
- Windows: abrir el Bloc de notas **como administrador** y editar
  `C:\Windows\System32\drivers\etc\hosts`; luego `ipconfig /flushdns`.

> `miproyecto.com` es un dominio real en Internet: si el navegador muestra otro sitio es que
> no está tomando el archivo hosts. Verificar con `getent hosts miproyecto.com`; en Firefox,
> desactivar *DNS sobre HTTPS* (Ajustes → Privacidad y seguridad).

---

## Parte 6 — GitHub y despliegue

### 6.1 Crear el repositorio y subir el código

1. En GitHub: **New repository** → nombre `miproyecto`, **Public**, *sin* README, .gitignore ni licencia.
   (Público para que el servidor pueda clonarlo sin credenciales; el repositorio no contiene ninguna contraseña.)
2. En la carpeta del proyecto (ya es un repositorio Git con la rama `main`):

```bash
cd ~/Sistemas/miproyecto
git remote add origin https://github.com/<USUARIO>/miproyecto.git
git push -u origin main
```

Si pide contraseña, GitHub no acepta la de la cuenta: usar un **token personal**
(GitHub → Settings → Developer settings → Personal access tokens → *Generate new token*, permiso `repo`).

3. Comprobar que no se publicaron credenciales:

```bash
git ls-files | grep -i config        # sólo config/config.example.php
git grep -n "'pass'"                 # sólo el valor de ejemplo y el código que lo lee
```

### 6.2 Clonar en el servidor

```bash
sudo bash setup/04_clonar_repositorio.sh https://github.com/<USUARIO>/miproyecto.git
```

Clona la rama `main` en `/var/www/miproyecto`, ajusta permisos e instala `deploy.sh`,
`backup.sh` y `restore.sh` en `/usr/local/bin`.

### 6.3 `deploy.sh`

`scripts/deploy.sh` (instalado como `/usr/local/bin/deploy.sh`):

1. `git fetch origin main` y muestra los commits nuevos.
2. `git reset --hard origin/main`: el servidor queda idéntico a GitHub.
3. `php -l` en todos los archivos PHP; **si hay un error de sintaxis vuelve a la versión anterior**.
4. Ajusta propietarios y permisos.
5. Recarga Apache y comprueba que `http://miproyecto.com` responda HTTP 200.
6. Registra todo en `/var/log/miproyecto/deploy.log`.

### 6.4 Demostración del despliegue (cambio visible)

El pie de página muestra **versión** y **commit desplegado**, así se ve el cambio enseguida.

```bash
cd ~/Sistemas/miproyecto
# 1. Cambio visible: nueva versión y un subtítulo distinto
sed -i "s/APP_VERSION = '1.0.0'/APP_VERSION = '1.1.0'/" src/bootstrap.php
sed -i 's/Registro de los equipos informáticos del centro de cómputos./Registro de equipos — actualizado desde GitHub con deploy.sh/' public/index.php
git diff
# 2. Subir a GitHub
git commit -am "Versión 1.1.0: cambio visible en la página principal"
git push
# 3. Desplegar en el servidor
sudo deploy.sh
```

Recargar `http://miproyecto.com`: aparece el nuevo subtítulo y el pie dice
*versión 1.1.0 · commit xxxxxxx* (el mismo hash que muestra GitHub).

También puede desplegar una desarrolladora: `su - carla` → `sudo deploy.sh`.

```bash
sudo tail -n 20 /var/log/miproyecto/deploy.log
```

---

## Parte 7 — Respaldos locales automáticos

```bash
sudo bash setup/07_respaldos_cron.sh
```

### Qué hace `backup.sh`

- Vuelca la base con `mariadb-dump --single-transaction` (consistente sin detener la app).
- Genera **un archivo por respaldo** en `/srv/respaldos/local/` (fuera de la carpeta pública):
  `miproyecto_AAAA-MM-DD_HHMMSS_<tipo>.tar.gz` con:
  - `basedatos.sql` — base completa
  - `var/www/miproyecto/` — archivos de la aplicación (sin `.git`)
  - `etc/miproyecto/` — configuración y credenciales
  - `etc/apache2/sites-available/miproyecto.com.conf` — VirtualHost
  - `INFO.txt` — fecha, servidor, commit desplegado
- Verifica el archivo y genera su suma `SHA-256` (`.sha256`).
- Permisos `640 root:respaldos`.
- **Retención**: conserva los últimos 4 de cada tipo (`KEEP_LOCAL=4` en `/etc/miproyecto/backup.conf`).
  Los tipos son `semanal` (crontab), `manual` y `prerestauracion`, así las pruebas manuales
  no desplazan a los 4 respaldos semanales.
- Registra cada ejecución en `/srv/respaldos/logs/backup.log` (y en el journal: `journalctl -t miproyecto-backup`).
- Código de salida: 0 = OK, 1 = falló el respaldo local, 2 = local OK pero falló la nube.

### Crontab

```
0 0 * * 6 /usr/local/bin/backup.sh --semanal >> /srv/respaldos/logs/cron.log 2>&1
```

| Campo | Valor | Significado |
|---|---|---|
| minuto | `0` | minuto 0 |
| hora | `0` | 00 h |
| día del mes | `*` | todos |
| mes | `*` | todos |
| día de la semana | `6` | sábado (0 = domingo) |

**Para mostrar al docente**

```bash
sudo crontab -l
sudo backup.sh                                   # ejecución manual
ls -lh /srv/respaldos/local/
sudo tail -n 15 /srv/respaldos/logs/backup.log
cd /srv/respaldos/local && sudo sha256sum -c "$(ls *.sha256 | tail -1)"
sudo tar -tzf "$(ls /srv/respaldos/local/*.tar.gz | tail -1)" | head -20
```

**Probar el cron sin esperar al sábado** (opcional): `sudo crontab -e`, agregar
`* * * * * /usr/local/bin/backup.sh --tipo=prueba-cron --solo-local >> /srv/respaldos/logs/cron.log 2>&1`,
esperar un minuto, comprobar con `ls /srv/respaldos/local` y `journalctl -u cron -n 5`,
y **borrar esa línea**.

---

## Parte 8 — Respaldos en la nube con Backblaze B2

### 8.1 En la web de Backblaze

1. Crear la cuenta en <https://www.backblaze.com> → **B2 Cloud Storage** (10 GB gratis).
2. **Buckets → Create a Bucket**
   - Nombre único, por ejemplo `miproyecto-respaldos-<tunombre>`
   - **Files in Bucket: Private**
   - Object Lock: desactivado
3. En el bucket → **Lifecycle Settings** → *Keep only the last version of the file*.
4. **Application Keys → Add a New Application Key**
   - Nombre: `rclone-miproyecto`
   - *Allow access to Bucket(s)*: el bucket creado
   - *Type of Access*: **Read and Write**
   - Copiar **keyID** y **applicationKey** (la clave se muestra **una sola vez**).

### 8.2 En el servidor

```bash
sudo bash setup/08_backblaze_rclone.sh
```

Instala Rclone, pide keyID / applicationKey / nombre del bucket, guarda la configuración en
`/root/.config/rclone/rclone.conf` (600, nunca en GitHub), prueba escribir/leer/borrar en el
bucket, configura `RCLONE_DEST` en `/etc/miproyecto/backup.conf` y ejecuta un respaldo completo.

Desde ese momento `backup.sh` (manual y del crontab) además:

- sube el `.tar.gz` y su `.sha256` a `b2:<bucket>/miproyecto/`,
- verifica que el tamaño en la nube coincida con el local,
- aplica la retención en la nube (`KEEP_CLOUD=4` por tipo, borrado definitivo),
- registra el resultado en `backup.log` y el detalle de Rclone en `rclone.log`.

**Para mostrar al docente**

```bash
sudo rclone lsd b2:                                 # buckets (si la clave lo permite)
sudo rclone ls b2:<bucket>/miproyecto               # respaldos en la nube
sudo restore.sh --listar --nube
sudo grep -i nube /srv/respaldos/logs/backup.log | tail
```

y en la web de Backblaze: *Buckets → Browse Files*.

### 8.3 Recuperar desde la nube

`restore.sh` descarga el respaldo, **verifica el SHA-256**, lo extrae en
`/srv/respaldos/restauracion/`, genera antes un respaldo de seguridad (`prerestauracion`) y
restaura la base y/o los archivos.

**Prueba segura** (no toca producción): restaurar la base en otra base y comparar.

```bash
sudo restore.sh --nube ultimo --solo-bd --bd-destino=miproyecto_prueba
sudo mariadb -e "SELECT COUNT(*) FROM miproyecto.equipos; SELECT COUNT(*) FROM miproyecto_prueba.equipos;"
sudo mariadb -e "DROP DATABASE miproyecto_prueba;"
```

**Simulacro de desastre** (la demostración más convincente):

```bash
sudo backup.sh                                            # 1. respaldo actual en la nube
# 2. "Desastre": eliminar varios equipos desde la web y borrar un archivo
sudo rm /var/www/miproyecto/public/assets/estilos.css     #    la página queda sin estilos
# 3. Recuperar desde Backblaze
sudo restore.sh --nube ultimo                             #    escribir SI para confirmar
# 4. Recargar http://miproyecto.com → vuelven los equipos y los estilos
sudo tail -n 15 /srv/respaldos/logs/restore.log
```

Otras opciones: `--solo-verificar` (descarga, verifica y extrae sin restaurar),
`--solo-archivos`, `--con-config` (restaura también `/etc/miproyecto`),
o un archivo concreto: `sudo restore.sh --nube miproyecto_2026-11-14_000000_semanal.tar.gz`.
Si el código del respaldo es más viejo que el de GitHub, `sudo deploy.sh` lo vuelve a sincronizar.

---

## Matriz de cumplimiento

| Requisito | Dónde / cómo se comprueba |
|---|---|
| Ubuntu/Debian, nombre de equipo, red, actualización | `hostnamectl`, `ip a`, `apt list --upgradable` · `01_sistema.sh` |
| Herramientas, SSH, directorios, recursos | `01_sistema.sh` · `bash setup/info_sistema.sh` |
| ≥5 usuarios en 3 grupos, contraseñas | 6 usuarios · `getent group …` · `02_usuarios_grupos.sh` |
| Directorios compartidos y privados, permisos | `/srv/*`, `/home/*`, ACL · `ls -ld`, `getfacl` |
| Crear/modificar/bloquear/eliminar usuarios | `02_demo_gestion_usuarios.sh` |
| Acceso sólo a recursos autorizados | `02_verificar_permisos.sh` · `su - carla` |
| Apache, PHP, MariaDB, Git, SSH sin Docker | `03_servicios.sh` · `systemctl status` |
| Inicio automático, start/stop/restart, estado, logs | `systemctl …`, `journalctl …` |
| Verificar Apache + PHP + BD | `http://miproyecto.com/estado.php` |
| App PHP: página, formulario, BD, listar, modificar, eliminar | `public/*.php` · navegador |
| `/var/www`, permisos, VirtualHost, hosts, dominio | `04`, `06_apache_vhost.sh` · `apache2ctl -S` |
| GitHub, clonar, `deploy.sh` desde `main`, cambio visible | §6 · pie de página con versión y commit |
| Sin credenciales en GitHub | `.gitignore`, `config.example.php`, `git ls-files` |
| `backup.sh`: archivos + BD, fecha/hora, log, 4 semanales | `/srv/respaldos/local`, `backup.log`, `KEEP_LOCAL=4` |
| Crontab `0 0 * * 6`, prueba manual | `sudo crontab -l` · `sudo backup.sh` |
| Respaldos fuera de la carpeta pública | `/srv/respaldos` (no está bajo `/var/www`) |
| Backblaze B2 privado, credenciales, Rclone, acceso | §8.1 · `08_backblaze_rclone.sh` |
| Subida integrada en `backup.sh`, 4 en la nube, log | `KEEP_CLOUD=4` · `backup.log`, `rclone.log` |
| Recuperar desde la nube archivos y base | `restore.sh --nube ultimo` · §8.3 |

---

## Lista de control para el día de la entrega

- [ ] Contenedores Docker detenidos (`sudo docker ps` vacío).
- [ ] `systemctl is-active apache2 mariadb ssh cron` → 4 × `active`.
- [ ] `http://miproyecto.com` y `/estado.php` cargan ("Todo funcionando").
- [ ] Repositorio de GitHub con el último código y el cambio visible desplegado.
- [ ] `sudo crontab -l` muestra la línea `0 0 * * 6`.
- [ ] Hay respaldos en `/srv/respaldos/local` **y** en Backblaze (`sudo restore.sh --listar --nube`).
- [ ] Contraseña de los usuarios de prueba a mano (para `su - carla`, `ssh ana@localhost`).

**Guion sugerido (≈10 minutos)**: `info_sistema.sh` → `02_verificar_permisos.sh` y `su - carla` →
`systemctl stop/start apache2` + `journalctl` → CRUD en el navegador → cambio visible, `git push`,
`sudo deploy.sh` → `sudo backup.sh` y `sudo crontab -l` → archivos en Backblaze →
simulacro de desastre y `sudo restore.sh --nube ultimo`.

---

## Solución de problemas

| Síntoma | Causa probable / solución |
|---|---|
| `miproyecto.com` abre otro sitio | Falta la línea en hosts o el navegador usa DNS sobre HTTPS. `getent hosts miproyecto.com` debe dar `127.0.0.1`. Escribir `http://`. |
| "Ocurrió un error" en la app | `sudo tail /var/log/apache2/miproyecto_error.log`. Si dice *Connection refused* / *No such file*: MariaDB detenido. *Access denied*: volver a ejecutar `05_base_datos.sh`. |
| MariaDB no arranca | Puerto 3306 ocupado por Docker: detener contenedores o usar el 3307 (ver §0). `sudo journalctl -u mariadb -n 30`. |
| `git push` rechaza la contraseña | Usar un token personal de GitHub. |
| `deploy.sh`: no puede contactar el remoto | Sin Internet o repositorio privado. El repositorio debe ser público (no tiene secretos). |
| `08_backblaze_rclone.sh`: `401 bad_auth_token` | keyID o applicationKey mal copiados; crear otra Application Key. |
| `backup.sh` termina con código 2 | Local OK, falló la nube: ver `/srv/respaldos/logs/rclone.log`. |
| El crontab no corrió | El equipo estaba apagado el sábado a las 00:00, o `cron` detenido: `systemctl status cron`, `journalctl -u cron`. |
| `sudo: … is not allowed to execute` | Comportamiento esperado: cada grupo sólo puede ejecutar sus scripts. |
