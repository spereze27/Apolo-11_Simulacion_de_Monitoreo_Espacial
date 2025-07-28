# 🛰️ Apolo-11 - Simulación de Monitoreo Espacial (NASA)

Este proyecto simula un sistema de monitoreo unificado para la NASA, como parte de la evaluación de conocimientos de linux del curso de "Analitica y big data" de la universidad nacional de Colombia. Representa el primer paso en el desarrollo de una infraestructura que permita supervisar en tiempo real el estado de componentes clave en futuras misiones espaciales.

Algunos cambios relevantes para tener en cuenta son que en el consolidado se saca adicionalmente el archivo FALLAS que recapitula todas las fallas registradas, esto se hizo para tener una mejor visual de lo que ocurre internamente en las misiones ya que no solo se quiere ver cuantos dispositivos han fallado sino tambien cuales.


## ⚠️ Recomendación importante

Antes de ejecutar el script, es necesario otorgar permisos de ejecución al archivo `Apolo-11.sh`. Para ello, en la terminal:

```bash
chmod +x Apolo-11.sh
```

El analisis de los datos se hace con sql por lo que asegurate de tener instalado sqlite3

```bash
sudo apt install sqlite3
```

El script `Apolo-11.sh` utiliza una estructura `case "$1"` que permite ejecutar acciones en función del argumento pasado (por ejemplo: `run`, `help`, etc.).  
Esto se hace con el objetivo de integrarlo con `cron`, un demonio del sistema (servicio que corre en segundo plano en Linux) que permite programar tareas para que se ejecuten automáticamente en intervalos definidos de tiempo.

---

## 📝 Cómo programar la ejecución con `cron`

1. Abre el editor de tareas de `cron` con:

```bash
crontab -e
```

2. Agrega la siguiente línea para ejecutar el script cada minuto:

```bash
* * * * * bash /ruta/absoluta/Apolo11/Apolo-11.sh run >> /ruta/absoluta/Apolo11/logs/apolo.log 2>&1
```

- El argumento `run` indica que se debe ejecutar el flujo principal del script.
- La redirección `>> ... 2>&1` guarda tanto la salida estándar como los errores en el archivo `apolo.log`.

---

## ⏱️ ¿Y si quiero que se ejecute cada 20 segundos?

`cron` solo permite una frecuencia mínima de **1 minuto**, pero puedes simular ejecuciones cada 20 segundos agregando varias líneas con `sleep`:

```bash
* * * * * bash /ruta/absoluta/Apolo11/Apolo-11.sh run >> /ruta/absoluta/Apolo11/logs/apolo.log 2>&1
* * * * * sleep 20; bash /ruta/absoluta/Apolo11/Apolo-11.sh run >> /ruta/absoluta/Apolo11/logs/apolo.log 2>&1
* * * * * sleep 40; bash /ruta/absoluta/Apolo11/Apolo-11.sh run >> /ruta/absoluta/Apolo11/logs/apolo.log 2>&1
```

Esto ejecutará el mismo script **tres veces por minuto**, con intervalos de 20 segundos entre cada ejecución.

## 🎯 Objetivo

La NASA busca evitar errores en sus misiones espaciales mediante un sistema de monitoreo basado en archivos generados automáticamente cada 20 segundos. Este sistema simula la recopilación de datos de distintos dispositivos (satélites, naves, trajes espaciales, etc.) para evaluar su estado.

Este programa:

- Genera un numero aleatorio de archivos con registros de dispositivos espaciales simulados (con misiones y dispositivos aleatorios).
- Consolida los datos diarios.
- Extrae en un consolidado aparte unicamente los registros de dispositivos en falla para poder identificar cuales puntualmente estan fallando
- Genera reportes analíticos que permiten evaluar el estado general de la flota espacial (cuantos registros llegan por mision, cuantos registros son de misiones desconocidas, cuantos dispositivos estan en falla por mision, etc.). 
- Mueve los archivos procesados a una carpeta de respaldo y limpia la carpeta de registros para mantener el entorno limpio y organizado.

---

## 📦 Archivos del proyecto

- `apolo-11.sh`: Script principal que ejecuta el ciclo de simulación.
- `config.sh`: Archivo de configuración donde se define:
  - Intervalos de simulación (número de archivos generados)
  - Misiones disponibles
  - Tipos de dispositivos disponibles
  - Estados posibles
  - Rutas de salida:
    - `LOG_FOLDER="./devices"` – Carpeta donde se guardan los archivos generados
    - `BACKUP_FOLDER="./backups"` – Carpeta donde se mueven los archivos procesados
    - `REPORT_FOLDER="./reports"` – Carpeta donde se guardan los reportes generados

- `README.md`: Este documento.

---

## 📁 Estructura generada

```text
.
├── apolo-11.sh
├── config.sh
├── /devices           # Archivos de simulación generados por cada ciclo
├── /reports           # Reportes consolidados y analíticos diarios
├── /backups           # Archivos ya procesados, movidos desde /devices
└── README.md
