#!/bin/bash

# ====================================================================
# KaliOptimus
#
# Descripción: Script para asegurar la configuración correcta de repositorios
#              y claves GPG de Kali Linux, descargar e instalar
#              manualmente el último 'kali-archive-keyring', e intentar
#              reforzar APT antes de realizar una actualización completa
#              del sistema. Incluye salida con colores para mejor legibilidad.
#
# Herramienta creada por: gustaafvito
# GitHub: https://github.com/Gustaafvito
# Versión: 1.0
# Fecha: 2025-05-13
#
# Licencia:
# Este script se distribuye bajo la Licencia MIT.
# Copyright (c) 2025 gustaafvito
# ====================================================================

# --- Definición de Colores ANSI ---
RESET='\033[0m'
BOLD='\033[1m'
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
BOLD_RED='\033[1;31m'
BOLD_GREEN='\033[1;32m'
BOLD_YELLOW='\033[1;33m'
BOLD_CYAN='\033[1;36m'
# --- Fin Colores ---

# --- Configuración ---
KALI_BRANCH="kali-rolling"
# Usar un mirror principal directo en lugar del redirector http.kali.org
KALI_REPO_LINE="deb https://kali.download/kali ${KALI_BRANCH} main non-free contrib"
KEYRING_POOL_URL="https://http.kali.org/kali/pool/main/k/kali-archive-keyring/"
KEYRING_DEB_TEMP_PATH="/tmp/kali-archive-keyring_latest.deb"
# --- Fin Configuración ---

# Variables para el estado final
dpkg_exit_code=0
download_exit_code=0 # Para la descarga del keyring
upgrade_failed=false
keyring_deb_filename_found=true # Asumimos que se encontrará, se pone a false si falla

# Función para imprimir mensajes de pasos
print_step() {
    printf "${BOLD_CYAN}--------------------------------------------------------------------${RESET}\n"
    printf "${BOLD_CYAN}PASO %s: %s${RESET}\n" "$1" "$2"
    printf "${BOLD_CYAN}--------------------------------------------------------------------${RESET}\n"
}

# --- PASO 0: Verificaciones Previas ---
print_step 0 "Verificaciones Previas"
printf "Verificando conexión a internet (intentando contactar https://kali.download)... "
if ! curl --silent --head --fail "https://kali.download/kali/" &> /dev/null; then
    printf "${BOLD_RED}ERROR${RESET}\n"; printf "${RED}No se pudo establecer conexión con https://kali.download.\nVerifica tu conexión a internet y/o configuración DNS.${RESET}\n"; exit 1
fi
printf "${BOLD_GREEN}OK${RESET}\n"

printf "Verificando si se ejecuta como root... "
if [ "$(id -u)" -ne 0 ]; then
   printf "${BOLD_RED}ERROR${RESET}\n"; printf "${RED}Este script necesita ser ejecutado como root (o con sudo).\n       Ejecútalo así: sudo ./KaliOptimus.sh${RESET}\n"; exit 1
fi
printf "${BOLD_GREEN}OK${RESET}\n"


# --- PASO 1: Configurar Repositorio Oficial ---
print_step 1 "Configurar Repositorio Oficial de Kali Linux (${KALI_BRANCH})"
printf "Este script configurará tu sistema para usar el repositorio oficial:\n   ${BOLD}%s${RESET}\n" "${KALI_REPO_LINE}"; echo ""
SOURCES_FILE="/etc/apt/sources.list"
if [ -f "${SOURCES_FILE}" ]; then printf "Se creará una copia de seguridad de tu ${BOLD}%s${RESET} actual.\n" "${SOURCES_FILE}"; else printf "El archivo ${BOLD}%s${RESET} no existe, se creará uno nuevo.\n" "${SOURCES_FILE}"; fi
printf "${BOLD_YELLOW}¿Deseas continuar y (re)configurar ${SOURCES_FILE}? (s/N):${RESET} "; read confirm_sources < /dev/tty
if [[ ! "$confirm_sources" =~ ^[Ss]$ ]]; then printf "${YELLOW}Operación cancelada por el usuario.${RESET}\n"; exit 0; fi
if [ -f "${SOURCES_FILE}" ]; then
    BACKUP_FILE="${SOURCES_FILE}.backup_$(date +%F_%H-%M-%S)"; printf "Creando copia de seguridad en %s... " "${BACKUP_FILE}"
    cp -a "${SOURCES_FILE}" "${BACKUP_FILE}"; if [ $? -eq 0 ]; then printf "${BOLD_GREEN}OK${RESET}\n"; else printf "${BOLD_RED}ERROR al copiar${RESET}\n"; exit 1; fi
fi
printf "Escribiendo nueva configuración en %s... " "${SOURCES_FILE}"; echo "${KALI_REPO_LINE}" | tee "${SOURCES_FILE}" > /dev/null
if [ $? -eq 0 ]; then printf "${BOLD_GREEN}OK${RESET}\n"; else printf "${BOLD_RED}ERROR al escribir${RESET}\n"; exit 1; fi
printf "${GREEN}Configuración de repositorio (%s) actualizada.${RESET}\n" "${SOURCES_FILE}"


# --- PASO 2: Limpiar Posibles Claves Antiguas ---
print_step 2 "Limpiar Posibles Claves GPG Antiguas"
OLD_KEY_FILES=( "/etc/apt/trusted.gpg.d/kali-archive-keyring.gpg" "/etc/apt/trusted.gpg" ); key_removed=false
printf "Buscando archivos de claves antiguas/manuales...\n"
for key_file in "${OLD_KEY_FILES[@]}"; do
    if [ -f "$key_file" ]; then
        printf "Eliminando posible archivo de clave antiguo/manual: %s... " "${key_file}"; rm -f "${key_file}"
        if [ $? -eq 0 ]; then printf "${BOLD_GREEN}OK${RESET}\n"; else printf "${BOLD_RED}ERROR al eliminar${RESET}\n"; fi; key_removed=true
    fi
done
if ! $key_removed; then printf "${YELLOW}No se encontraron archivos de claves antiguas comunes para eliminar.${RESET}\n"; fi


# --- PASO 3: Descargar Último Keyring Manualmente ---
print_step 3 "Descargar Último Keyring Manualmente"
printf "Intentando encontrar la URL del último paquete 'kali-archive-keyring' desde:\n   %s\n" "${KEYRING_POOL_URL}"
LATEST_KEYRING_DEB_FILENAME=$(curl -s "${KEYRING_POOL_URL}" | grep -oE 'href="kali-archive-keyring_[0-9._-]+_all\.deb"' | cut -d'"' -f2 | sort -V | tail -n 1)
if [ -z "$LATEST_KEYRING_DEB_FILENAME" ]; then
    printf "${BOLD_RED}ERROR: No se pudo determinar el último archivo .deb del keyring desde ${KEYRING_POOL_URL}${RESET}\n" >&2
    printf "${RED}El comando 'grep' no encontró coincidencias.${RESET}\n" >&2
    keyring_deb_filename_found=false
else
    LATEST_KEYRING_URL="${KEYRING_POOL_URL}${LATEST_KEYRING_DEB_FILENAME}"
    printf "Último keyring encontrado: ${BOLD}%s${RESET}\n" "${LATEST_KEYRING_DEB_FILENAME}"
    printf "Descargando a %s... " "${KEYRING_DEB_TEMP_PATH}"; curl --silent --location --fail --output "${KEYRING_DEB_TEMP_PATH}" "${LATEST_KEYRING_URL}"; download_exit_code=$?
    if [ $download_exit_code -ne 0 ]; then
        printf "${BOLD_RED}ERROR (código %s)${RESET}\n" "$download_exit_code"; printf "${RED}Fallo al descargar ${LATEST_KEYRING_URL}${RESET}\n" >&2; rm -f "${KEYRING_DEB_TEMP_PATH}"; keyring_deb_filename_found=false
    elif ! file "${KEYRING_DEB_TEMP_PATH}" | grep -q "Debian binary package"; then
        printf "${BOLD_RED}ERROR${RESET}\n"; printf "${RED}El archivo descargado (%s) no parece ser un paquete Debian válido.${RESET}\n" "${KEYRING_DEB_TEMP_PATH}" >&2
        printf "${RED}Verifica la URL: ${LATEST_KEYRING_URL}${RESET}\n" >&2; rm -f "${KEYRING_DEB_TEMP_PATH}"; keyring_deb_filename_found=false
    else
        download_size=$(du -h "${KEYRING_DEB_TEMP_PATH}" | cut -f1); printf "${BOLD_GREEN}OK${RESET} (%s)\n" "${download_size}"
    fi
fi

# --- PASO 4: Instalar Keyring Manualmente con dpkg ---
if [ "$keyring_deb_filename_found" = true ]; then
    print_step 4 "Instalar Keyring Descargado Manualmente"
    printf "Instalando %s usando 'dpkg -i'...\n" "${KEYRING_DEB_TEMP_PATH}"; dpkg -i "${KEYRING_DEB_TEMP_PATH}"; dpkg_exit_code=$?
    printf "Limpiando archivo temporal %s... " "${KEYRING_DEB_TEMP_PATH}"; rm -f "${KEYRING_DEB_TEMP_PATH}"; printf "${BOLD_GREEN}OK${RESET}\n"
    if [ $dpkg_exit_code -ne 0 ]; then
        printf "${BOLD_RED}ERROR CRÍTICO: Falló la instalación del keyring con 'dpkg -i' (código %s).${RESET}\n" "$dpkg_exit_code" >&2
        printf "${RED}Revisa los mensajes de error anteriores.${RESET}\n" >&2
        upgrade_failed=true # Un fallo aquí impide el upgrade
    else
        printf "${BOLD_GREEN}'kali-archive-keyring' instalado/actualizado desde archivo .deb.${RESET}\n"
    fi
else
    print_step 4 "Instalar Keyring Descargado Manualmente - ${BOLD_RED}OMITIDO${RESET}"
    printf "${RED}No se pudo descargar el keyring en el Paso 3, por lo tanto se omite la instalación.${RESET}\n"
    upgrade_failed=true # Es un fallo que impide el upgrade
fi


# --- PASO 5: Actualizar Lista de Paquetes ---
if [ "$upgrade_failed" = false ]; then
    print_step 5 "Actualizar Lista de Paquetes (Post-Instalación Manual Keyring)"
    printf "Actualizando la lista de paquetes ('apt-get update'), ahora con las claves correctas instaladas...\n"; apt-get update
    if [ $? -ne 0 ]; then
        printf "${BOLD_RED}ERROR CRÍTICO: 'apt-get update' falló incluso después de instalar manualmente el keyring.${RESET}\n" >&2
        printf "${RED}Revisa tu configuración de red, DNS y los mensajes de error.${RESET}\n" >&2
        printf "${RED}Asegúrate que ${SOURCES_FILE} contiene la línea correcta: ${BOLD}%s${RESET}${RED}.${RESET}\n" "${KALI_REPO_LINE}" >&2; upgrade_failed=true
    else
        printf "${BOLD_GREEN}Lista de paquetes actualizada correctamente.${RESET}\n"
    fi
else
    print_step 5 "Actualizar Lista de Paquetes - ${BOLD_RED}OMITIDO${RESET}"
    printf "${RED}Omitido debido a fallo en paso anterior (keyring).${RESET}\n"
fi

# --- PASO 6: Preparación para Actualización Completa y Ejecución ---
if [ "$upgrade_failed" = false ]; then
    print_step 6 "Preparación y Actualización Completa del Sistema (full-upgrade)"
    printf "Limpiando caché de APT antes de la actualización...\n"; apt-get clean
    if [ $? -eq 0 ]; then printf "${GREEN}Caché de APT limpiado.${RESET}\n"; else printf "${YELLOW}Advertencia: 'apt-get clean' falló o no hizo nada.${RESET}\n"; fi
    printf "Intentando reinstalar/actualizar componentes clave de APT y SSL...\n"
    apt-get install --reinstall -y apt apt-transport-https ca-certificates openssl libssl3t64 libgnutls30t64 || \
    printf "${BOLD_YELLOW}ADVERTENCIA: No se pudieron reinstalar/actualizar todos los componentes de APT/SSL. Continuando de todos modos...${RESET}\n"

    printf "Se procederá a actualizar todos los paquetes del sistema a sus últimas versiones.\n"
    printf "${YELLOW}Esto puede llevar bastante tiempo y descargar/instalar muchos datos.${RESET}\n"
    printf "${BOLD_YELLOW}¿Deseas iniciar la actualización completa ('apt full-upgrade')? (s/N):${RESET} "
    read confirm_upgrade < /dev/tty
    if [[ ! "$confirm_upgrade" =~ ^[Ss]$ ]]; then printf "${YELLOW}Operación de actualización cancelada.${RESET}\n"; upgrade_failed=true;
    else
        printf "Iniciando 'apt-get -o Acquire::ForceIPv4=true full-upgrade -y' (puede tardar)...\n"
        apt-get -o Acquire::ForceIPv4=true full-upgrade -y
        upgrade_exit_code=$?
        if [ $upgrade_exit_code -ne 0 ]; then
            printf "${BOLD_RED}ERROR: 'apt full-upgrade' encontró un problema (código %s).${RESET}\n" "$upgrade_exit_code" >&2
            printf "${RED}El error 'Method https has died' es persistente o ha ocurrido otro error durante el upgrade.\n" >&2
            printf "${YELLOW}Acciones Manuales Sugeridas:\n" >&2
            printf "${YELLOW}  a) Ejecuta: sudo apt --fix-broken install\n" >&2
            printf "${YELLOW}  b) Revisa tu configuración de red/firewall. Intenta en otra red si es posible.${RESET}\n" >&2
            upgrade_failed=true
        else
            printf "${BOLD_GREEN}Actualización completa ('full-upgrade') terminada con éxito.${RESET}\n"
        fi
    fi
else
    print_step 6 "Preparación y Actualización Completa del Sistema - ${BOLD_RED}OMITIDO${RESET}"
    printf "${RED}Omitido debido a fallo en paso anterior.${RESET}\n"
fi

# --- PASO 7: Limpieza Post-Actualización ---
print_step 7 "Limpieza Post-Actualización"
printf "Eliminando paquetes que ya no son necesarios ('autoremove')... "
apt-get autoremove -y &> /dev/null
if [ $? -eq 0 ]; then printf "${BOLD_GREEN}OK${RESET}\n"; else printf "${BOLD_YELLOW}Advertencia (autoremove falló/no hizo nada)${RESET}\n"; fi
printf "Limpiando caché de paquetes descargados ('clean')... "
apt-get clean &> /dev/null
if [ $? -eq 0 ]; then printf "${BOLD_GREEN}OK${RESET}\n"; else printf "${BOLD_YELLOW}Advertencia (clean falló)${RESET}\n"; fi
printf "${GREEN}Limpieza completada.${RESET}\n"


# --- PASO 8: Finalización ---
print_step 8 "Finalización"
printf "${BOLD_CYAN}--------------------------------------------------------------------${RESET}\n"
final_message=""
if [ "$keyring_deb_filename_found" = false ] || [ $dpkg_exit_code -ne 0 ] || [ $upgrade_failed = true ]; then
    final_message="${BOLD_RED}¡ATENCIÓN! El script finalizó, pero hubo errores en uno o más pasos críticos.${RESET}\n"
    final_message+="${RED}El sistema puede no estar completamente actualizado o en un estado inconsistente. Revisa los mensajes anteriores y las sugerencias.${RESET}\n"
else
    final_message="${BOLD_GREEN}¡El script de actualización y mantenimiento ha finalizado con éxito!${RESET}\n"
fi
printf "%b" "${final_message}"

printf "${BOLD_CYAN}--------------------------------------------------------------------${RESET}\n"
printf "${BOLD}RESUMEN DE ACCIONES:${RESET}\n"
printf "${GREEN}✓${RESET} Verificación de conexión y permisos realizada.\n"
printf "${GREEN}✓${RESET} Repositorio (%s) configurado para: ${BOLD}%s${RESET}\n" "${SOURCES_FILE}" "${KALI_REPO_LINE}"

keyring_summary_status="${GREEN}✓${RESET}"
keyring_summary_message="Claves de firma (kali-archive-keyring) descargadas e instaladas manualmente."
if [ "$keyring_deb_filename_found" = false ]; then
    keyring_summary_status="${RED}✗${RESET}"
    keyring_summary_message="Claves de firma: Falló la búsqueda/descarga del keyring."
elif [ $dpkg_exit_code -ne 0 ]; then
    keyring_summary_status="${RED}✗${RESET}"
    keyring_summary_message="Claves de firma: Falló la instalación del keyring descargado."
fi
printf "%s %s\n" "${keyring_summary_status}" "${keyring_summary_message}"

upgrade_summary_status="${GREEN}✓${RESET}"
upgrade_summary_message="Sistema actualizado ('full-upgrade')."
if [ "$upgrade_failed" = true ]; then
    upgrade_summary_status="${RED}✗${RESET}"
    # Ajuste para que el mensaje de "No intentada" solo aparezca si el keyring falló
    if [ "$keyring_deb_filename_found" = false ] || [ $dpkg_exit_code -ne 0 ]; then
        upgrade_summary_message="Actualización del sistema: No intentada debido a error previo con keyring."
    else
        upgrade_summary_message="Actualización del sistema ('full-upgrade') fallida o incompleta."
    fi
fi
printf "%s %s\n" "${upgrade_summary_status}" "${upgrade_summary_message}"

# La limpieza se intenta siempre, así que la marcamos como ✓ a menos que queramos verificar su código de salida
printf "${GREEN}✓${RESET} Limpieza realizada ('autoremove', 'clean').\n"

echo ""
printf "Si la actualización fue exitosa (o parcialmente exitosa) y se actualizaron componentes clave,\n"
printf "es ${BOLD}MUY recomendable reiniciar${RESET} el sistema.\n"
printf "Puedes hacerlo con el comando: ${BOLD}sudo reboot${RESET}\n"
printf "${BOLD_CYAN}--------------------------------------------------------------------${RESET}\n"
printf "Script v1.0 por gustaafvito (${CYAN}https://github.com/Gustaafvito${RESET})\n"
printf "Nombre del Script: ${BOLD}KaliOptimus${RESET}\n"
printf "${BOLD_CYAN}--------------------------------------------------------------------${RESET}\n"

final_exit_code=0
if [ "$upgrade_failed" = true ] || [ "$keyring_deb_filename_found" = false ] || [ $dpkg_exit_code -ne 0 ]; then
    final_exit_code=1
fi
exit $final_exit_code
