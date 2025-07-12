#!/bin/bash

###############################################
# CONFIGURACIÓN GENERAL DEL SISTEMA APOLO-11
# Todas las variables pueden ser modificadas
###############################################

# === RUTAS DE TRABAJO ===
LOG_FOLDER="./devices"        # Carpeta donde se guardan los archivos generados
BACKUP_FOLDER="./backups"     # Carpeta donde se mueven los archivos procesados
REPORT_FOLDER="./reports"     # Carpeta donde se guardan los reportes generados

# === CICLO DE SIMULACIÓN ===
CYCLE_SECONDS=200              # Tiempo (en segundos) entre cada ejecución
MAX_FILES=100                 # Cantidad máxima de archivos a generar por ciclo
MIN_FILES=1                   # Cantidad mínima de archivos por ciclo

# === TIMESTAMP ===
# Formato de la fecha/hora en los logs (ej: 120725153045 → 12 Jul 2025, 15:30:45)
TIMESTAMP_FORMAT="%d%m%y%H%M%S"
# === Formato de consolidado diario (sin hora)
DAILY_FORMAT="%d%m%y"


# === MISIONES DISPONIBLES ===
MISSIONS=("ORBONE" "CLNM" "TMRS" "GALXONE" "UNKN")

# === TIPOS DE DISPOSITIVO ===
DEVICE_TYPES=("satellite" "ship" "spacesuit" "vehicle")

# === ESTADOS POSIBLES DE DISPOSITIVO ===
STATUSES=("excellent" "good" "warning" "faulty" "killed" "unknown")

# === NOMENCLATURA DE ARCHIVOS ===
LOG_PREFIX="APL"               # Prefijo para archivos de simulación
REPORT_PREFIX="APLSTATS"       # Prefijo para reportes generados

# === OTROS ===
FIELD_SEPARATOR=$'\t'          # Separador usado en los archivos .log

