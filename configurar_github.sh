#!/bin/bash

# ==============================================================================
# Script para Configurar Múltiples Cuentas de GitHub con Claves SSH Dedicadas
#
# Autor: Gemini
# Versión: 1.0
#
# Descripción:
# Este script interactivo automatiza el proceso de generar una nueva clave SSH
# para una cuenta de GitHub específica, la agrega a la configuración de SSH
# y proporciona las instrucciones necesarias para completar el proceso.
# Esto permite gestionar múltiples cuentas de GitHub en una sola máquina
# sin conflictos.
#
# Uso:
# 1. Guarda este script como 'configurar_github.sh'.
# 2. Dale permisos de ejecución: chmod +x configurar_github.sh
# 3. Ejecútalo: ./configurar_github.sh
# 4. Sigue las instrucciones en pantalla.
# ==============================================================================

# --- Definición de Colores para la Salida ---
COLOR_VERDE='\033[0;32m'
COLOR_AMARILLO='\033[1;33m'
COLOR_CIAN='\033[0;36m'
COLOR_ROJO='\033[0;31m'
SIN_COLOR='\033[0m'

# --- Función para Imprimir Encabezados ---
print_header() {
    echo -e "${COLOR_CIAN}===============================================================${SIN_COLOR}"
    echo -e "${COLOR_CIAN}  $1"
    echo -e "${COLOR_CIAN}===============================================================${SIN_COLOR}"
}

# --- Inicio del Script ---
clear
print_header "Asistente de Configuración de Cuentas de GitHub"
echo -e "Este script te ayudará a configurar una nueva cuenta de GitHub con su propia clave SSH."
echo ""

# --- Paso 1: Solicitar Información al Usuario ---
echo -e "${COLOR_AMARILLO}Primero, necesito algunos datos de la cuenta de GitHub que quieres agregar.${SIN_COLOR}"
read -p "Introduce tu nombre de usuario de GitHub (ej: Cod3Crack): " GITHUB_USER
read -p "Introduce el email asociado a esa cuenta de GitHub: " GITHUB_EMAIL

# Validar que los campos no estén vacíos
if [ -z "$GITHUB_USER" ] || [ -z "$GITHUB_EMAIL" ]; then
    echo -e "\n${COLOR_ROJO}Error: El nombre de usuario y el email no pueden estar vacíos. Abortando.${SIN_COLOR}"
    exit 1
fi

echo ""
print_header "Paso 1: Generando una Nueva Clave SSH"

# Definir la ruta del archivo de la clave SSH
SSH_KEY_PATH="$HOME/.ssh/id_rsa_$GITHUB_USER"

# Comprobar si ya existe una clave con ese nombre
if [ -f "$SSH_KEY_PATH" ]; then
    echo -e "${COLOR_AMARILLO}Advertencia: Ya existe una clave en '${SSH_KEY_PATH}'.${SIN_COLOR}"
    read -p "¿Quieres sobrescribirla? (s/N): " OVERWRITE
    if [[ "$OVERWRITE" != "s" && "$OVERWRITE" != "S" ]]; then
        echo -e "${COLOR_ROJO}Operación cancelada por el usuario.${SIN_COLOR}"
        exit 1
    fi
fi

echo "Se generará una clave para '${GITHUB_EMAIL}'."
echo "Cuando se te pida una 'passphrase', simplemente presiona Enter para dejarla en blanco."
echo ""

# Generar la clave SSH de forma no interactiva
ssh-keygen -t rsa -b 4096 -C "$GITHUB_EMAIL" -f "$SSH_KEY_PATH" -N ""

# Comprobar si la clave se generó correctamente
if [ $? -ne 0 ]; then
    echo -e "\n${COLOR_ROJO}Error: Hubo un problema al generar la clave SSH. Abortando.${SIN_COLOR}"
    exit 1
fi

echo -e "\n${COLOR_VERDE}¡Clave SSH generada exitosamente en '${SSH_KEY_PATH}'!${SIN_COLOR}"
echo ""


# --- Paso 2: Agregar la Clave Pública a GitHub ---
print_header "Paso 2: Agrega tu Nueva Clave Pública a GitHub"
echo -e "Ahora necesitas decirle a GitHub que confíe en tu nueva clave."
echo -e "El contenido de tu clave ${COLOR_AMARILLO}pública${SIN_COLOR} es el siguiente:"
echo ""
echo -e "${COLOR_CIAN}--- INICIO DE LA CLAVE PÚBLICA (copia todo este bloque) ---${SIN_COLOR}"
cat "${SSH_KEY_PATH}.pub"
echo -e "${COLOR_CIAN}--- FIN DE LA CLAVE PÚBLICA ---${SIN_COLOR}"
echo ""
echo "Sigue estos pasos:"
echo "  1. Copia la clave pública que se muestra arriba (desde 'ssh-rsa' hasta el final)."
echo "  2. Abre tu navegador y ve a GitHub.com, iniciando sesión en la cuenta de '${GITHUB_USER}'."
echo "  3. Ve a ${COLOR_AMARILLO}Settings > SSH and GPG keys${SIN_COLOR}."
echo "  4. Haz clic en el botón ${COLOR_VERDE}'New SSH key'${SIN_COLOR}."
echo "  5. Dale un Título (ej: 'Mi Portátil de Trabajo') y pega la clave en el campo 'Key'."
echo "  6. Haz clic en ${COLOR_VERDE}'Add SSH key'${SIN_COLOR}."
echo ""
read -p "Presiona Enter cuando hayas terminado de agregar la clave en GitHub..."

# --- Paso 3: Configurar el Archivo de Configuración SSH ---
print_header "Paso 3: Configurando el 'Llavero Inteligente' (SSH Config)"
echo "Ahora, vamos a decirle a tu sistema cuándo usar esta nueva clave."

# Crear el directorio .ssh si no existe
mkdir -p "$HOME/.ssh"
chmod 700 "$HOME/.ssh"

# Definir el archivo de configuración
SSH_CONFIG_PATH="$HOME/.ssh/config"
touch "$SSH_CONFIG_PATH" # Asegurarse de que el archivo exista

# Crear el "apodo" para el host
HOST_ALIAS="github.com-$GITHUB_USER"

# Comprobar si el host ya está configurado para evitar duplicados
if grep -q "Host $HOST_ALIAS" "$SSH_CONFIG_PATH"; then
    echo -e "${COLOR_AMARILLO}El host '${HOST_ALIAS}' ya está configurado en tu archivo ~/.ssh/config. No se realizarán cambios.${SIN_COLOR}"
else
    echo "Agregando la nueva configuración al archivo ~/.ssh/config..."
    # Agregar la configuración al final del archivo
    {
        echo ""
        echo "# Cuenta de GitHub para $GITHUB_USER"
        echo "Host $HOST_ALIAS"
        echo "    HostName github.com"
        echo "    User git"
        echo "    IdentityFile $SSH_KEY_PATH"
        echo "    IdentitiesOnly yes"
    } >> "$SSH_CONFIG_PATH"
    echo -e "${COLOR_VERDE}¡Configuración agregada correctamente!${SIN_COLOR}"
fi
echo ""

# --- Paso 4: Instrucciones Finales ---
print_header "Paso 4: ¡Todo Listo! Cómo Usar tu Nueva Configuración"
echo -e "Tu sistema ya está preparado. Ahora, así es como lo usas con tus repositorios:"
echo ""
echo -e "${COLOR_AMARILLO}Opción A) Para clonar un repositorio NUEVO:${SIN_COLOR}"
echo "Usa este formato. Reemplaza 'repo.git' con el nombre de tu repositorio."
echo -e "${COLOR_CIAN}git clone git@${HOST_ALIAS}:${GITHUB_USER}/repo.git${SIN_COLOR}"
echo ""
echo -e "${COLOR_AMARILLO}Opción B) Para un repositorio que YA TIENES clonado:${SIN_COLOR}"
echo "1. Navega a la carpeta de tu repositorio:"
echo -e "${COLOR_CIAN}cd /ruta/a/tu/repositorio${SIN_COLOR}"
echo "2. Ejecuta este comando para actualizar la URL remota:"
echo -e "${COLOR_CIAN}git remote set-url origin git@${HOST_ALIAS}:${GITHUB_USER}/repo.git${SIN_COLOR}"
echo ""
echo -e "${COLOR_VERDE}¡Proceso completado! Ya puedes trabajar con la cuenta de '${GITHUB_USER}' de forma segura.${SIN_COLOR}"
echo ""

