#!/bin/bash

# ==============================================================================
# Script para automatizar la configuración de una aplicación Flask
# con Gunicorn, Nginx y Certbot (SSL) en un servidor Ubuntu.
# Versión modularizada y genérica para cualquier tipo de aplicación web.
# ==============================================================================

# --- Colores para una mejor legibilidad ---
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # Sin Color

# --- Función para manejar errores ---
# Si un comando falla, el script se detendrá.
check_error() {
    if [ $? -ne 0 ]; then
        echo -e "${RED}Error: Ocurrió un problema en el último paso. Abortando script.${NC}"
        exit 1
    fi
}

# --- Bienvenida y obtención de IP Pública ---
echo -e "${BLUE}--- Asistente de Configuración de Aplicación Web en Ubuntu ---${NC}"
echo "Este script te ayudará a configurar todo lo necesario."
echo ""

echo -e "${BLUE}>>> Obteniendo tu IP Pública...${NC}"
# Usamos -s para modo silencioso y guardamos la IP en una variable
PUBLIC_IP=$(curl -s ifconfig.me)
check_error

if [ -z "$PUBLIC_IP" ]; then
    echo -e "${RED}No se pudo obtener la IP pública. Verifica tu conexión a internet.${NC}"
    exit 1
fi

echo -e "La IP pública de tu servidor es: ${GREEN}$PUBLIC_IP${NC}"
echo -e "${YELLOW}Acción Requerida:${NC} Ve al panel de control de tu dominio y asegúrate de que tu subdominio"
echo "apunte a esta IP mediante un registro DNS de tipo 'A'."
echo "La propagación del DNS puede tardar unos minutos."
echo ""
read -p "$(echo -e ${YELLOW}'Presiona Enter para continuar una vez que hayas configurado el DNS... '${NC})"

# --- Recolección de datos ---
echo ""
echo "Por favor, responde a las siguientes preguntas."
echo ""

# Se establecen valores fijos
USERNAME="ubuntu"
PYTHON_FILE="app"
FLASK_APP_VAR="app"
echo -e "${GREEN}El nombre de usuario se ha establecido automáticamente como: ${BLUE}$USERNAME${NC}"
echo -e "${GREEN}El archivo de la aplicación se ha establecido como: ${BLUE}${PYTHON_FILE}.py${NC}"
echo -e "${GREEN}La variable de Flask se ha establecido como: ${BLUE}$FLASK_APP_VAR${NC}"


# Preguntar por el subdominio
read -p "$(echo -e ${YELLOW}'1. Introduce tu subdominio (ej: app.dominio.com): '${NC})" SUBDOMAIN
if [ -z "$SUBDOMAIN" ]; then
    echo -e "${RED}El subdominio no puede estar vacío. Abortando.${NC}"
    exit 1
fi

# Preguntar por la carpeta del proyecto. Este nombre se usará también para el entorno y el servicio.
read -p "$(echo -e ${YELLOW}'2. Introduce el nombre de la carpeta de tu proyecto (que está en /home/'$USERNAME'/github/): '${NC})" PROJECT_FOLDER
if [ -z "$PROJECT_FOLDER" ]; then
    echo -e "${RED}El nombre de la carpeta del proyecto no puede estar vacío. Abortando.${NC}"
    exit 1
fi

# Construir las rutas completas. El nombre del entorno es el mismo que el del proyecto.
APP_PATH="/home/$USERNAME/github/$PROJECT_FOLDER"
VENV_PATH="/home/$USERNAME/entorno/$PROJECT_FOLDER"

# Verificar que la ruta del proyecto existe
if [ ! -d "$APP_PATH" ]; then
    echo -e "${RED}La ruta del proyecto '$APP_PATH' no existe. Verifica el nombre de la carpeta. Abortando.${NC}"
    exit 1
fi

# Preguntar por el puerto
read -p "$(echo -e ${YELLOW}'3. Introduce el puerto para la aplicación (default: 8000): '${NC})" PORT
# Si no se introduce puerto, usar 8000 por defecto
PORT=${PORT:-8000}

echo ""
echo -e "${GREEN}¡Gracias! Iniciando la configuración con los siguientes datos:${NC}"
echo -e "Subdominio: ${BLUE}$SUBDOMAIN${NC}"
echo -e "Usuario del servicio: ${BLUE}$USERNAME${NC}"
echo -e "Ruta de la App: ${BLUE}$APP_PATH${NC}"
echo -e "Ruta del Entorno Virtual: ${BLUE}$VENV_PATH${NC}"
echo -e "Comando Gunicorn: ${BLUE}${PYTHON_FILE}:${FLASK_APP_VAR}${NC}"
echo -e "Puerto de la aplicación: ${BLUE}$PORT${NC}"
echo ""
read -p "$(echo -e ${YELLOW}'¿Son correctos estos datos? (s/n): '${NC})" confirmation
if [[ "$confirmation" != "s" && "$confirmation" != "S" ]]; then
    echo -e "${RED}Configuración cancelada por el usuario.${NC}"
    exit 1
fi

# --- PASO 1: INSTALAR DEPENDENCIAS ---
echo -e "\n${BLUE}>>> Paso 1: Actualizando e instalando dependencias (curl, Nginx, Python, Certbot)...${NC}"
sudo apt update
check_error
sudo apt install -y curl nginx python3-pip python3-venv certbot python3-certbot-nginx
check_error
echo -e "${GREEN}Dependencias instaladas correctamente.${NC}"

# --- PASO 2 y 3: ENTORNO VIRTUAL Y DEPENDENCIAS PYTHON ---
echo -e "\n${BLUE}>>> Paso 2 y 3: Creando entorno virtual en $VENV_PATH e instalando dependencias...${NC}"
# Crear el directorio base del entorno si no existe y asignar permisos
sudo mkdir -p "/home/$USERNAME/entorno"
sudo chown $USERNAME:$USERNAME "/home/$USERNAME/entorno"
check_error

python3 -m venv "$VENV_PATH"
check_error
source "$VENV_PATH/bin/activate"
check_error
pip install flask gunicorn
check_error
deactivate
echo -e "${GREEN}Entorno virtual y paquetes de Python configurados.${NC}"

# --- PASO 4 y 5: CONFIGURACIÓN DE NGINX ---
echo -e "\n${BLUE}>>> Paso 4 y 5: Creando el archivo de configuración de Nginx para $SUBDOMAIN...${NC}"
NGINX_CONF_FILE="/etc/nginx/sites-available/$SUBDOMAIN"
sudo bash -c "cat > $NGINX_CONF_FILE" <<EOF
server {
    listen 80;
    server_name $SUBDOMAIN;

    location / {
        proxy_pass http://127.0.0.1:$PORT;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF
check_error
echo -e "${GREEN}Archivo de configuración de Nginx creado en $NGINX_CONF_FILE.${NC}"

# --- PASO 6: HABILITAR SITIO NGINX ---
echo -e "\n${BLUE}>>> Paso 6: Habilitando el sitio, probando configuración y reiniciando Nginx...${NC}"
sudo ln -s -f "$NGINX_CONF_FILE" "/etc/nginx/sites-enabled/"
check_error
sudo nginx -t
check_error
sudo systemctl restart nginx
check_error
echo -e "${GREEN}Sitio de Nginx habilitado y servicio reiniciado.${NC}"

# --- PASO 7: OBTENER CERTIFICADO SSL ---
echo -e "\n${BLUE}>>> Paso 7: Obteniendo certificado SSL con Certbot...${NC}"
echo "Certbot te podría hacer algunas preguntas para completar el proceso (como tu email)."
echo "Se recomienda elegir la opción de redirigir el tráfico HTTP a HTTPS cuando se pregunte."
sudo certbot --nginx -d "$SUBDOMAIN"
check_error
echo -e "${GREEN}Certificado SSL configurado. Tu sitio ya debería ser accesible por HTTPS.${NC}"

# --- PASO 8 y 9: CREAR SERVICIO SYSTEMD ---
SERVICE_NAME="${PROJECT_FOLDER//./-}" # Usa el nombre de la carpeta del proyecto como base para el servicio
SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"
echo -e "\n${BLUE}>>> Paso 8 y 9: Creando el archivo de servicio systemd en ${SERVICE_FILE}...${NC}"

sudo bash -c "cat > $SERVICE_FILE" <<EOF
[Unit]
Description=Gunicorn instance to serve the application $PROJECT_FOLDER
After=network.target

[Service]
User=$USERNAME
Group=www-data
WorkingDirectory=$APP_PATH
Environment="PATH=$VENV_PATH/bin"
ExecStart=$VENV_PATH/bin/gunicorn --workers 3 --bind 127.0.0.1:$PORT ${PYTHON_FILE}:${FLASK_APP_VAR}
Restart=always

[Install]
WantedBy=multi-user.target
EOF
check_error
echo -e "${GREEN}Archivo de servicio systemd creado.${NC}"

# --- PASO 10 y 11: INICIAR Y HABILITAR EL SERVICIO ---
echo -e "\n${BLUE}>>> Paso 10 y 11: Recargando systemd, iniciando y habilitando el servicio...${NC}"
sudo systemctl daemon-reload
check_error
sudo systemctl start "$SERVICE_NAME"
check_error
sudo systemctl enable "$SERVICE_NAME"
check_error
echo -e "${GREEN}¡Servicio iniciado y habilitado para arrancar con el sistema!${NC}"

# --- FINALIZACIÓN ---
echo -e "\n\n${GREEN}====================================================="
echo -e "¡PROCESO DE CONFIGURACIÓN COMPLETADO CON ÉXITO!"
echo -e "=====================================================${NC}"
echo ""
echo -e "Tu aplicación debería estar funcionando en: ${BLUE}https://www.$SUBDOMAIN${NC}"
echo ""
echo -e "${YELLOW}--- Comandos útiles para gestionar tu servicio ---${NC}"
echo -e "Ver el estado del servicio:"
echo -e "${GREEN}sudo systemctl status $SERVICE_NAME${NC}"
echo ""
echo -e "Ver los logs en tiempo real:"
echo -e "${GREEN}sudo journalctl -u $SERVICE_NAME -f${NC}"
echo ""
echo -e "Reiniciar el servicio después de un cambio en el código:"
echo -e "${GREEN}sudo systemctl restart $SERVICE_NAME${NC}"
echo ""
echo -e "Detener el servicio:"
echo -e "${GREEN}sudo systemctl stop $SERVICE_NAME${NC}"
echo ""
