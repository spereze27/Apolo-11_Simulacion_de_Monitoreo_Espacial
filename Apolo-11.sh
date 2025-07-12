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
  done
}

# Genera el archivo de reporte analítico del día en base al consolidado diario.
# Este reporte incluye:
# - Análisis de la cantidad de eventos por estado, misión y dispositivo.
# - Identificación de dispositivos con mayor número de desconexiones (estado "unknown").
# - Consolidación de dispositivos inoperables (estado "faulty").
# - Cálculo de porcentajes de registros por misión.
# - Cálculo de porcentajes de registros por tipo de dispositivo.
# El archivo se guarda en el directorio de reportes con el nombre: APLSTATS-REPORTE-ddmmyy-HHMMSS.log
# Para mantener un solo reporte por día, se elimina cualquier reporte anterior del mismo día antes de generar uno nuevo.
generate_reports() {
  local timestamp=$(date +"%d%m%y%H%M%S")                         # Fecha y hora completa
  local consolidated_file="${REPORT_FOLDER}/${REPORT_PREFIX}-CONSOLIDADO-$(date +"$DAILY_FORMAT").log"
  local report_file="${REPORT_FOLDER}/${REPORT_PREFIX}-REPORTE-${timestamp}.log"

  # Verifica que exista el consolidado para el día evaluado
  if [[ ! -f "$consolidated_file" ]]; then
    echo "❌ Consolidado no encontrado: $consolidated_file"
    return
  fi

  # Elimina reportes anteriores del mismo día para mantener un solo reporte diario actualizado
  # unicamente quiero un archivo que resuma los estadisticos por dia y le dejo el timestamp de hhmmss para poder identificar cuando se actualizo por ultima vez
  # si no quisiera ver cuando se actualizo por ultima vez simplemente lo llamaria con DDMMYY y lo sobreescribiria, por eso se eliminan.
  # El patrón busca cualquier archivo que empiece por APLSTATS-REPORTE- y tenga el mismo día (ddmmyy)
  rm -f "${REPORT_FOLDER}/${REPORT_PREFIX}-REPORTE-${timestamp:0:6}"*.log

  # Cuenta la cantidad total de registros (sin contar el header)
  local total=$(grep -v "^date" "$consolidated_file" | wc -l)

  {
    echo "===== REPORTE GENERAL - $timestamp ====="
    echo ""

    ### 1. Análisis de eventos por estado, misión y dispositivo
    # Cuenta cuántas veces ocurre cada combinación de:
    # $2: misión, $3: tipo de dispositivo, $4: estado
    # Se excluye el encabezado (NR > 1) y se ordena de mayor a menor
    echo "--- Análisis de eventos por estado, misión y dispositivo ---"
    awk -F "$FIELD_SEPARATOR" '
      NR > 1 {
        combo = $2 FS $3 FS $4
        count[combo]++
      }
      END {
        for (c in count) print count[c] FS c
      }
    ' "$consolidated_file" | sort -nr
    echo ""

    ### 2. Gestión de desconexiones (estado: unknown)
    # Agrupa por misión y dispositivo, contando solo registros con estado "unknown"
    echo "--- Dispositivos con más desconexiones (estado: unknown) por misión ---"
    awk -F "$FIELD_SEPARATOR" '
      NR > 1 && $4 == "unknown" {
        key = $2 FS $3
        discon[key]++
      }
      END {
        for (k in discon) print discon[k] FS k
      }
    ' "$consolidated_file" | sort -nr
    echo ""

    ### 3. Dispositivos inoperables por misión (estado: faulty)
    # Agrupa por misión y dispositivo, contando solo los registros "faulty"
    echo "--- Dispositivos inoperables por misión (estado: faulty) ---"
    awk -F "$FIELD_SEPARATOR" '
      NR > 1 && $4 == "faulty" {
        key = $2 FS $3
        faults[key]++
      }
      END {
        for (k in faults) print faults[k] FS k
      }
    ' "$consolidated_file" | sort -nr
    echo ""

    ### 4. Porcentajes de registros por misión
    # Cuenta cuántas veces aparece cada misión, calcula su porcentaje y ordena de mayor a menor
    echo "--- Porcentaje de registros por misión ---"
    awk -F "$FIELD_SEPARATOR" -v total="$total" '
      NR > 1 { mission[$2]++ }
      END {
        for (m in mission) {
          pct = (mission[m] / total) * 100
          printf "%.2f\t%s\n", pct, m
        }
      }
    ' "$consolidated_file" | sort -nr | awk '{ printf "%s\t%s%%\n", $2, $1 }'
    echo ""

    ### 5. Porcentajes de registros por tipo de dispositivo
    # Analogo al porcentaje de cada mision
    echo "--- Porcentaje de registros por tipo de dispositivo ---"
    awk -F "$FIELD_SEPARATOR" -v total="$total" '
      NR > 1 { dev[$3]++ }
      END {
        for (d in dev) {
          pct = (dev[d] / total) * 100
          printf "%.2f\t%s\n", pct, d
        }
      }
    ' "$consolidated_file" | sort -nr | awk '{ printf "%s\t%s%%\n", $2, $1 }'
    echo ""

  } > "$report_file"      # Esto hace que todo se grabe en el registro, si no se enviara al report se imprimiria en pantalla

  #echo "✅ Reporte actualizado: $(basename "$report_file")"
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

main_loop() {
  echo "🛰️  Iniciando ciclo automático Apolo-11 (cada $CYCLE_SECONDS segundos)..."
  init_directories
  
  # Captura de interrupción con Ctrl+C, esto es unicamente para identificar cuando se interrumpe la ejecución del sistema
  trap 'echo -e "\n🚨 Ejecución interrumpida por el usuario. Cerrando Apolo-11..."; exit 0' INT


  while true; do
    echo ""
    echo "🕒 Nueva ejecución: $(date)"
    
    generate_files
    consolidate_files
    generate_reports
    move_to_backup

    echo "⏳ Esperando $CYCLE_SECONDS segundos para la siguiente ejecución..."
    sleep "$CYCLE_SECONDS"
  done
}

main_loop


