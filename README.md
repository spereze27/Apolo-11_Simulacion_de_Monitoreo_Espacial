# 🛰️ Apolo-11 - Simulación de Monitoreo Espacial (NASA)

Este proyecto simula un sistema de monitoreo unificado para la NASA, como parte de la evaluación de conocimientos de linux del curso de "Analitica y big data" de la universidad nacional de Colombia. Representa el primer paso en el desarrollo de una infraestructura que permita supervisar en tiempo real el estado de componentes clave en futuras misiones espaciales.

Algunos cambios relevantes para tener en cuenta son que en el consolidado se saca adicionalmente el archivo FALLAS que recapitula todas las fallas registradas, esto se hizo para tener una mejor visual de lo que ocurre internamente en las misiones ya que no solo se quiere ver cuantos dispositivos han fallado sino tambien cuales.


## ⚠️ Recomendación importante

Antes de ejecutar el script, es necesario otorgar permisos de ejecución al archivo `apolo-11.sh`. Para ello, ejecute en la terminal:

chmod +x apolo-11.sh

Por favor tenga en cuenta definir cada cuanto se debe correr el programa Apolo-11.sh en el config (variable CYCLE_SECONDS=20, el 20 esta por default y son 20 segundos), si se desea cambiar el tiempo de ejecucion posterior al comienzo de la operacion se debe detener el programa (control + C en el terminal) y modificar desde el config el tiempo de corrida del programa


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
