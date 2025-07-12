# === Cargar configuración ===
CONFIG_FILE="./config.sh"
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
  local mission_index=$((RANDOM % ${#MISSIONS[@]}))
  local mission=${MISSIONS[$mission_index]}
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
  echo "Cantidad de archivos a generar: $file_count"

  for ((i = 1; i <= file_count; i++)); do
    # Elegir misión aleatoria
    local mission_index=$((RANDOM % ${#MISSIONS[@]}))
    local mission=${MISSIONS[$mission_index]}

    # Generar nombre base y agregar timestamp para unicidad
    local filename=$(generate_filename)               # APL-[ORBONE|CLNM|TMRS|GALXONE|UNKN]-0000[1-100].log

    # Crear contenido del archivo
    local log_line=$(generate_log_entry "$mission")

    # Guardar en carpeta devices/
    echo -e "$log_line" > "${LOG_FOLDER}/${filename}"
    echo "Archivo creado: $filename"
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
    else
      log_hash=$(cut -f5 "$file")
      echo "⚠️ Archivo ignorado por fecha inválida: $file"
      echo "   → Fecha encontrada: $log_date (esperada: $day_id)"
      echo "   → Hash en el archivo: $log_hash"
    fi
  done
}

generate_reports() {
  local day_id=$(date +"$DAILY_FORMAT")
  local consolidated_file="${REPORT_FOLDER}/${REPORT_PREFIX}-CONSOLIDADO-${day_id}.log"
  local report_file="${REPORT_FOLDER}/${REPORT_PREFIX}-REPORTE-${day_id}.log"

  if [[ ! -f "$consolidated_file" ]]; then
    echo "❌ Consolidado no encontrado: $consolidated_file"
    return
  fi

  {
    echo "===== REPORTE DIARIO - $day_id ====="
    echo ""

    echo "--- Eventos por misión ---"
    cut -f2 "$consolidated_file" | grep -v -e "^mission$" \
      | sort | uniq -c | sort -nr \
      | awk '{ printf "%-5s %s\n", $1, $2 }'
    echo ""

    echo "--- Estados de dispositivos ---"
    cut -f4 "$consolidated_file" | grep -v -e "^device_status$" \
      | sort | uniq -c | sort -nr \
      | awk '{ printf "%-5s %s\n", $1, $2 }'
    echo ""

    echo "--- Registros desconocidos (misión UNKN) ---"
    grep -P "${FIELD_SEPARATOR}UNKN${FIELD_SEPARATOR}" "$consolidated_file" | wc -l
  } > "$report_file"
}


generate_reports


