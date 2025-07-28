#!/bin/bash

# === Cargar configuración (ruta absoluta del script) ===
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/config.sh"

if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "ERROR: Archivo de configuración '$CONFIG_FILE' no encontrado."
  exit 1
fi
source "$CONFIG_FILE"

# === Función: Crear directorios si no existen ===
init_directories() {
  mkdir -p "$LOG_FOLDER"
  mkdir -p "$BACKUP_FOLDER"
  mkdir -p "$REPORT_FOLDER"
}

# === Función: Generar timestamp actual con formato configurable ===
# El formato se encuentra en el config
generate_timestamp() {
  date +"$TIMESTAMP_FORMAT"
}

# === Función: Generar nombre de archivo aleatorio ===
# Se usa local para definir la variable local dentro de la funcion generate_filename(), es decir que solamente es visible dentro de la funcion y no se llama desde afuera
# Esta funcion unicamente genera el nombre del archivo con las misiones ("ORBONE" "CLNM" "TMRS" "GALXONE" "UNKN")
# Primero se genera un indice aleatorio entre 0 y la longitud del array misions menos 1, es decir que al tener 5 misiones 
# entonces el indice es entre 0 y 4
# Se selecciona el elemento del array misions que tiene el indice aleatorio generado
# Por ultimo se genera el sufijo del archivo generado con 5 ceros antes del numero del archivo
generate_filename() {
  local mission="$1"
  local number=$(printf "%05d" $((RANDOM % (MAX_FILES - MIN_FILES + 1) + MIN_FILES)))
  echo "${LOG_PREFIX}-${mission}-${number}.log"
}


# === Función: Generar hash SHA256 si misión es conocida ===
# Se genera la huella digital del documento (Hash) que sirve para ubicar y trackear el archivo
# En este caso se usa el algoritmo SHA-256, que devuelve una cadena de 64 caracteres hexadecimal.
# El hash es (fecha + misión + tipo de dispositivo + estado) cuando la mision es conocida
generate_hash() {
  local string="$1"
  echo -n "$string" | sha256sum | awk '{print $1}'
}

# === Función: Generar contenido del archivo log en forma tabular ===
# Primero llamamos la marca de tiempo en el formato ya definido en el config
# Se guarda el primer argumento recibido por la función generate_log_entry() en la variable local mission.
# Si la mision es UNKN (desconocida) entonces se pone el registro de tiempo y que la mision es desconocida, los demas campos son desconocidos
# Si la mision no es desconocida se escogen de manera aleatoria los dispositivos y el status
# Se genera el hash para rastrear el registro
generate_log_entry() {
  local timestamp=$(generate_timestamp)
  local mission="$1"

  if [[ "$mission" == "UNKN" ]]; then
    echo -e "${timestamp}${FIELD_SEPARATOR}${mission}${FIELD_SEPARATOR}unknown${FIELD_SEPARATOR}unknown${FIELD_SEPARATOR}unknown"
  else
    local device=${DEVICE_TYPES[$((RANDOM % ${#DEVICE_TYPES[@]}))]}
    local status=${STATUSES[$((RANDOM % ${#STATUSES[@]}))]}
    local hash=$(generate_hash "${timestamp}${mission}${device}${status}")
    echo -e "${timestamp}${FIELD_SEPARATOR}${mission}${FIELD_SEPARATOR}${device}${FIELD_SEPARATOR}${status}${FIELD_SEPARATOR}${hash}"
  fi
}

# === Función: Generar múltiples archivos simulados por ciclo ===
# Primero se calcula cuantos archivos se van a generar en esta corrida entre MIN_FILES y MAX_FILES (estan en el config).
# Cuando se genera un archivo primero selecciono a que mision corresponde ese archivo
# Se genera el nombre del archivo correspondiente a lo establecido en los requerimientos, esto se hace con la funcion generate_filename
# Se agrega el contenido del log para almacenar en el archivo
# Se guarda en la carpeta devices
generate_files() {
  # Cuántos archivos se generarán este ciclo
  local file_count=$((RANDOM % (MAX_FILES - MIN_FILES + 1) + MIN_FILES))

  for ((i = 1; i <= file_count; i++)); do
    # Elegir misión aleatoria
    local mission_index=$((RANDOM % ${#MISSIONS[@]}))
    local mission=${MISSIONS[$mission_index]}

    # Generar nombre base y agregar timestamp para unicidad
    local filename=$(generate_filename "$mission")               # APL-[ORBONE|CLNM|TMRS|GALXONE|UNKN]-0000[1-100].log

    # Crear contenido del archivo
    local log_line=$(generate_log_entry "$mission")

    # Guardar en carpeta devices/
    echo -e "$log_line" > "${LOG_FOLDER}/${filename}"
  done
}

# Se consolidan los reportes en un solo archivo por día, el formato esta definido en DAILY FORMAT (d%m%y)
# Si el archivo aún no existe, escribe la primera línea (header) con los nombres de columnas.
# En cada log se lee la primera columna del archivo (la fecha completa del evento) y extrae los primeros 6 caracteres (ddmmaa)
# Compara si el día en la línea del archivo coincide con el día actual y de ser asi añade su registro al consolidado del dia.
consolidate_files() {
  local day_id=$(date +"$DAILY_FORMAT")
  local output_file="${REPORT_FOLDER}/${REPORT_PREFIX}-CONSOLIDADO-${day_id}.log"

  # Crear encabezado solo si el archivo aún no existe
  if [[ ! -f "$output_file" ]]; then
    echo -e "date${FIELD_SEPARATOR}mission${FIELD_SEPARATOR}device_type${FIELD_SEPARATOR}device_status${FIELD_SEPARATOR}hash" > "$output_file"
  fi

  # Recorrer archivos .log de devices/
  for file in "${LOG_FOLDER}"/*.log; do
    [[ -e "$file" ]] || continue

    # Leer la primera columna (fecha completa) del archivo (esto para verificar que los reportes correspondan al dia que los resume)
    # Esto puede parecer redundante ya que los archivos .log se moveran a la carpeta de backup pero esta verificación se realiza con el fin de detectar 
    # corrupcion en las fechas o formatos.
    log_date=$(cut -f1 "$file")          # ej: 120724153012
    log_day="${log_date:0:6}"            # extrae los primeros 6 caracteres → ddmmAA

    # Comparar con el día actual
    if [[ "$log_day" == "$day_id" ]]; then
      cat "$file" >> "$output_file"
    # En caso de tener archivos con fechas inconsistentes se notifica en consola de cual es el hash del archivo invalido
    else
      log_hash=$(cut -f5 "$file")
      echo "⚠️ Archivo ignorado por fecha inválida: $file"
      echo "   → Fecha encontrada: $log_date (esperada: $day_id)"
      echo "   → Hash en el archivo: $log_hash"
    fi
    # === Generar archivo separado con dispositivos en falla (estado "faulty") ===
    # Se busca poder hacer un seguimiento mas riguroso a los dispositivos que presentan fallos
    # Se extrae en un archivo aparte unicamente los registros con fallas.
    # El nombre incluye la fecha del día, por ejemplo: FALLAS-120724.log
    local faults_file="${REPORT_FOLDER}/FALLAS-${day_id}.log"

    # Reinicia el archivo si ya existía
    echo -e "date${FIELD_SEPARATOR}mission${FIELD_SEPARATOR}device_type${FIELD_SEPARATOR}device_status${FIELD_SEPARATOR}hash" > "$faults_file"

    # Filtra los registros "faulty" y los añade
    awk -F "$FIELD_SEPARATOR" '$4 == "faulty"' "$output_file" >> "$faults_file"
  done
}

# === Función: generate_reports_sql ===
# Esta función realiza los análisis estadísticos diarios de los eventos registrados por misión.
# En lugar de usar Bash puro (awk, grep, etc.), se opta por usar SQLite3 por eficiencia, legibilidad y escalabilidad.
#
#  ¿Por qué usar SQLite?
# - SQLite permite realizar consultas complejas de forma declarativa, eficiente y fácil de mantener.
# - Se crea una base de datos **temporal y liviana** directamente sobre el archivo consolidado del día.
# - No requiere instalación de un servidor ni credenciales de acceso: todo se ejecuta de forma local y segura.
#
#  ¿Qué se analiza?
# - Distribución de eventos por estado, misión y tipo de dispositivo.
# - Identificación de desconexiones (`unknown`) y fallas (`faulty`) por dispositivo y misión.
# - Porcentajes de participación por misión y por tipo de dispositivo.
#
#  La base de datos se elimina al sobreescribirse en la siguiente ejecución, por lo que su uso es transitorio.
#  El resultado final se guarda en un archivo de reporte con timestamp para identificar cuándo se generó.

generate_reports_sql() {
  # Generar marca de tiempo actual con formato: ddmmaahhmmss
  local timestamp=$(date +"%d%m%y%H%M%S")
  # Obtener el ID del día con el formato especificado en DAILY_FORMAT (ddmmaa)
  local day_id=$(date +"$DAILY_FORMAT")
  # Ruta al archivo consolidado de eventos del día
  local consolidated_file="${REPORT_FOLDER}/${REPORT_PREFIX}-CONSOLIDADO-${day_id}.log"
  # Nombre del archivo de reporte que se generará
  local report_file="${REPORT_FOLDER}/${REPORT_PREFIX}-REPORTE-${timestamp}.log"
  # Base de datos SQLite donde se importan los datos del consolidado
  local sqlite_db="${REPORT_FOLDER}/apolo_reports.db"
  # Nombre de la tabla en SQLite (una por día)
  local table_name="logs_${day_id}"

  # Verificar si el archivo consolidado existe antes de continuar
  if [[ ! -f "$consolidated_file" ]]; then
    echo "❌ Consolidado no encontrado: $consolidated_file"
    return
  fi
  # Eliminar reportes anteriores del mismo día para evitar duplicados
  rm -f "${REPORT_FOLDER}/${REPORT_PREFIX}-REPORTE-${timestamp:0:6}"*.log

  # Crear la base de datos (si no existe) e importar el archivo consolidado como tabla CSV usando ; como separador
sqlite3 "$sqlite_db" <<EOF
.mode csv
.separator ";"
.import $consolidated_file $table_name
EOF

  {
    echo "===== REPORTE GENERAL - $timestamp ====="
    echo ""
  # Análisis 1: Eventos agrupados por misión, tipo de dispositivo y estado
    echo "--- Análisis de eventos por estado, misión y dispositivo ---"
    sqlite3 "$sqlite_db" <<EOF
.headers off
.mode tabs
SELECT COUNT(*), mission, device_type, device_status
FROM $table_name
GROUP BY mission, device_type, device_status
ORDER BY COUNT(*) DESC;
EOF
    echo ""
  # Análisis 2: Dispositivos con más desconexiones (estado 'unknown')
    echo "--- Dispositivos con más desconexiones (estado: unknown) por misión ---"
    sqlite3 "$sqlite_db" <<EOF
SELECT COUNT(*), mission, device_type
FROM $table_name
WHERE device_status = 'unknown'
GROUP BY mission, device_type
ORDER BY COUNT(*) DESC;
EOF
    echo ""
  # Análisis 3: Dispositivos en falla (estado 'faulty')
    echo "--- Dispositivos inoperables por misión (estado: faulty) ---"
    sqlite3 "$sqlite_db" <<EOF
SELECT COUNT(*), mission, device_type
FROM $table_name
WHERE device_status = 'faulty'
GROUP BY mission, device_type
ORDER BY COUNT(*) DESC;
EOF
    echo ""
  # Análisis 4: Porcentaje de registros por misión
    echo "--- Porcentaje de registros por misión ---"
    sqlite3 "$sqlite_db" <<EOF
WITH total (cnt) AS (SELECT COUNT(*) FROM $table_name)
SELECT ROUND(100.0 * COUNT(*) / (SELECT cnt FROM total), 2) || '%', mission
FROM $table_name
GROUP BY mission
ORDER BY COUNT(*) DESC;
EOF
    echo ""
  # Análisis 5: Porcentaje de registros por tipo de dispositivo
    echo "--- Porcentaje de registros por tipo de dispositivo ---"
    sqlite3 "$sqlite_db" <<EOF
WITH total (cnt) AS (SELECT COUNT(*) FROM $table_name)
SELECT ROUND(100.0 * COUNT(*) / (SELECT cnt FROM total), 2) || '%', device_type
FROM $table_name
GROUP BY device_type
ORDER BY COUNT(*) DESC;
EOF
    echo ""
  } > "$report_file"
}


# Movemos los archivos ya procesados de devices a backups
move_to_backup() {
  #echo "Moviendo archivos .log a la carpeta de respaldo..."

  # Activa la opción nullglob: si no hay archivos .log, el patrón *.log no se deja como texto,
  # sino que se convierte en un array vacío. Así evitamos errores al iterar sobre archivos inexistentes.
  # shopt sirve para interactuar con el shell
  shopt -s nullglob  # evita errores si no hay archivos
  local files=("${LOG_FOLDER}"/*.log)

  if [[ ${#files[@]} -eq 0 ]]; then
    #echo "✅ No hay archivos para mover."
    return
  fi

  # Mueve cada archivo a la carpeta backup
  for file in "${files[@]}"; do
    mv "$file" "$BACKUP_FOLDER/"
  done

  #echo "✅ Archivos movidos a $BACKUP_FOLDER"
}

# Se ajusta para correr el proceso desde la terminal, case "$1" verifica el primer argumento que se pasó al script (ej: run, help)
# esto se hace con el objetivo de automatizar la tarea con chron ( un demonio del sistema (es decir, un servicio que corre en segundo plano en Linux)
# que se encarga de ejecutar tareas automáticamente en intervalos de tiempo definidos.)
# para cargar el chron se debe poner en terminal crontab -e para editar el chron y agregar * * * * * ruta_absoluta_al_folder_Apolo-11/Apolo-11.sh run >> ruta_absoluta_al_folder_Apolo-11/logs/apolo.log 2>&1
# la parte ruta_absoluta_al_folder_Apolo-11/logs/apolo.log 2>&1 unicamente es para llevar el registro de los logs del sistema
# Importante resaltar que chron funciona con intervalos de minutos por lo que si se desea que sea cada 20 segundos es necesario agregar varias veces la linea de ejecucion
# y darle un sleep de los tiempos deseados por ejemplo para ejecutar cada 20 segundos seria:
# * * * * * /home/quind/GIT/Apolo11/Apolo-11.sh run >> /home/quind/GIT/Apolo11/logs/apolo.log 2>&1
# * * * * * sleep 20; /home/quind/GIT/Apolo11/Apolo-11.sh run >> /home/quind/GIT/Apolo11/logs/apolo.log 2>&1
# * * * * * sleep 40; /home/quind/GIT/Apolo11/Apolo-11.sh run >> /home/quind/GIT/Apolo11/logs/apolo.log 2>&1
# esto ejecutara 3 veces el archivo con intervalos de 20 segundos

case "$1" in
  "run")
    echo "🛰️  Ejecutando ciclo Apolo-11"
    init_directories
    generate_files
    consolidate_files
    generate_reports_sql
    move_to_backup
    ;;
  *)
    echo "❌ Uso inválido. Prueba: $0 run"
    exit 1
    ;;
esac


