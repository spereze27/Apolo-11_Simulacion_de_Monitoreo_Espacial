# 🛰️ Apolo-11 - Simulación de Monitoreo Espacial (NASA)

Este proyecto simula un sistema de monitoreo unificado para la NASA, como parte de una evaluación del curso "Introducción a Linux". Representa el primer paso en el desarrollo de una infraestructura que permita supervisar en tiempo real el estado de componentes clave en futuras misiones espaciales.

---

## 🎯 Objetivo

La NASA busca evitar errores en sus misiones espaciales mediante un sistema de monitoreo basado en archivos generados automáticamente cada 20 segundos. Este sistema simula la recopilación de datos de distintos dispositivos (satélites, naves, trajes espaciales, etc.) para evaluar su estado.

Este programa:

- Genera archivos con registros de dispositivos espaciales simulados.
- Consolida los datos diarios.
- Genera reportes analíticos que permiten evaluar el estado general de la flota espacial.
- Mueve los archivos procesados a una carpeta de respaldo para mantener el entorno limpio y organizado.

---

## ⚙️ Requisitos

- Bash Shell (Linux o WSL en Windows)
- `sha256sum`, `awk`, `grep`, `sort`, `cut`, `mkdir`, `sleep`, `rm`, `date` (comandos estándar de Unix/Linux)

---

## 📦 Archivos del proyecto

- `apolo-11.sh`: Script principal que ejecuta el ciclo de simulación.
- `config.sh`: Archivo de configuración donde defines:
  - Intervalos de simulación
  - Misiones
  - Tipos de dispositivos
  - Estados posibles
  - Rutas de salida
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
