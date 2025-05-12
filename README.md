# KaliOptimus v1.0

**Herramienta creada por:** gustaafvito
**GitHub:** https://github.com/Gustaafvito 
**Versión:** 1.0
**Fecha:** 2025-05-13

## Descripción

KaliOptimus es un script de Bash diseñado para facilitar el mantenimiento y la actualización de sistemas Kali Linux. Sus principales funciones son:

* Asegurar que la configuración de repositorios (`/etc/apt/sources.list`) apunte a las fuentes oficiales de Kali Rolling.
* Resolver problemas comunes con las claves GPG de los repositorios de Kali, descargando e instalando manualmente la versión más reciente del paquete `kali-archive-keyring`.
* Intentar reforzar los componentes clave de `apt` y SSL/TLS antes de una actualización mayor.
* Realizar una actualización completa del sistema (`apt full-upgrade`).
* Limpiar paquetes innecesarios y el caché de `apt` después de la actualización.
* Proporcionar una salida con colores en la terminal para una mejor legibilidad del proceso.

Este script fue desarrollado para solucionar problemas persistentes durante el proceso de actualización, como errores de GPG o fallos en la descarga de paquetes debido a problemas con las conexiones HTTPS de `apt`.

## Características Principales

* **Configuración Automática de Repositorios:** Establece `kali.download` como la fuente principal para `kali-rolling`.
* **Reparación de Claves GPG:** Descarga e instala la última versión de `kali-archive-keyring`.
* **Refuerzo de APT:** Intenta reinstalar `apt`, `apt-transport-https`, `ca-certificates`, `openssl` y bibliotecas SSL relevantes.
* **Actualización Segura:** Utiliza la opción `Acquire::ForceIPv4=true` durante el `full-upgrade` para mitigar posibles problemas de red.
* **Interactivo:** Pide confirmación antes de realizar cambios críticos en el sistema (como modificar `sources.list` o iniciar el `full-upgrade`).
* **Salida Coloreada:** Mejora la experiencia del usuario con una salida clara y coloreada para cada paso, advertencia o error.
* **Copias de Seguridad:** Crea una copia de seguridad de `/etc/apt/sources.list` antes de modificarlo.
* **Limpieza:** Ejecuta `apt autoremove` y `apt clean` al finalizar.

## Requisitos

* Un sistema Kali Linux.
* Acceso a internet.
* Privilegios de superusuario (root) para ejecutar el script.
* Herramientas comunes de línea de comandos como `curl`, `grep`, `sort`, `tee`, `dpkg`, `apt` (que normalmente ya están instaladas en Kali).

## ¿Cómo Usar KaliOptimus?

1.  **Descargar el Script:**
    Puedes clonar el repositorio o descargar el archivo `KaliOptimus.sh` directamente.

2.  **Dar Permisos de Ejecución:**
    Abre una terminal y navega hasta el directorio donde guardaste el script. Luego, ejecuta:
    ```bash
    chmod +x KaliOptimus.sh
    ```

3.  **Ejecutar el Script:**
    Ejecuta el script con privilegios de superusuario:
    ```bash
    sudo ./KaliOptimus.sh
    ```
    El script te guiará a través de los pasos y te pedirá confirmación en momentos clave.

## Solución de Problemas

* **Error "Method https has died unexpectedly!" o "La declaración 'ssl' no se cumple." durante `apt full-upgrade`:**
    Este script intenta mitigar este problema forzando IPv4 y reinstalando componentes de SSL/APT. Si el error persiste, puede deberse a:
    * Problemas con tu red local (firewall, proxy, ISP, DNS). Intenta conectarte a una red diferente.
    * Corrupción más profunda en las bibliotecas SSL/TLS o en `apt`.
    * Problemas con el mirror específico de Kali al que te estás conectando.
    * **Acciones manuales sugeridas:**
        * `sudo apt --fix-broken install`
        * `sudo dpkg --configure -a`
        * Revisar logs (`/var/log/apt/term.log`, `/var/log/syslog`).
        * Buscar el error específico en foros de la comunidad Kali.

* **No se puede determinar el último archivo .deb del keyring:**
    El script intenta obtener el último `kali-archive-keyring` parseando la página del pool de Kali. Si la estructura de esa página cambia drásticamente, este paso podría fallar. El script debería indicar este error.

## Licencia

Este proyecto se distribuye bajo la **Licencia MIT**. Consulta el archivo `LICENSE` para más detalles.

---

¡Esperamos que KaliOptimus te sea de utilidad!

