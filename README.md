# La Clínica del Informático

## Requisitos

- PostgreSQL 18 en ejecución y la base `clinica_informatica` creada.
- Java 25 (LTS) para el backend (instalador en `INSTALAR/jdk-25_windows-x64_bin.msi`). El script de inicio selecciona un JDK 25 instalado y configura `JAVA_HOME` para Maven; para compilar manualmente, selecciona también ese JDK en `JAVA_HOME`.
- Node.js y npm para Angular.
- Herramientas cliente de PostgreSQL (`pg_dump` y `pg_restore`) para generar y probar respaldos.

Flyway aplica automáticamente las migraciones pendientes al iniciar el backend.

## Inicio en Windows

Desde la carpeta raíz del proyecto, inicia el backend:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\scripts\Start-Backend.ps1"
```

El script solicita la contraseña de PostgreSQL la primera vez y la guarda cifrada para el usuario actual de Windows. Para volver a guardarla, ejecuta el mismo comando con `-ActualizarClave`.

En otra terminal, inicia Angular:

```powershell
Set-Location ".\frontend"
npm.cmd install
npm.cmd start
```

Abre la URL local que muestre Angular. La configuración de proxy envía las solicitudes `/api` al backend en `localhost:8080`.

## Gemini y respaldos

Gemini es opcional para iniciar el backend. Obtén una clave de Gemini API desde Google AI Studio y ejecuta el script de backend. En el primer inicio, el script la solicita de forma oculta y la guarda cifrada con DPAPI para el usuario actual de Windows; no la introduzcas en el código ni la compartas por chat. Para actualizarla ejecuta el script con `-ActualizarClaveGemini`. También se puede definir `GEMINI_API_KEY` en el entorno del proceso. El modelo predeterminado es `gemini-3.8-flash`; si necesitas otro, configúralo mediante `GEMINI_MODEL`. El monitoreo solo confirma la disponibilidad después de una solicitud de prediagnóstico real; no llama a Gemini cada vez que se abre la pantalla.

La generación administrativa de respaldos requiere `pg_dump` ejecutable por la cuenta del backend. Configura `PG_DUMP_PATH` si no está en `PATH`; opcionalmente configura `CLINICA_BACKUP_DIR` para cambiar la carpeta protegida de respaldos (por defecto, `%USERPROFILE%\clinica-backups`). Los respaldos se generan en formato custom y se pueden descargar desde la pantalla **Respaldos**. También se genera uno automáticamente cada día a las 02:00 UTC y se eliminan las copias completadas después de 30 días. Puedes ajustar el horario con `CLINICA_BACKUP_CRON`, la zona con `CLINICA_BACKUP_TIME_ZONE` y la retención con `CLINICA_BACKUP_RETENTION_DAYS`.

En Railway, configura el servicio del backend para usar el directorio raíz `/backend`; el [Dockerfile](./backend/Dockerfile) instala `pg_dump` 18. Adjunta un volumen persistente al servicio en `/data/backups` y define `CLINICA_BACKUP_DIR=/data/backups`. Sin el volumen, los archivos locales del contenedor pueden perderse al redeplegar; las copias no sustituyen los respaldos administrados de PostgreSQL en Railway.

Para probar una restauración, utiliza exclusivamente una base de datos temporal y sigue el procedimiento de [database/README.md](./backend/database/README.md). No restaures sobre la base activa.

## Módulos Sprint 6

Los indicadores, auditoría, respaldos y monitoreo requieren permisos administrativos. Los conteos y filtros de indicadores se calculan en el backend desde PostgreSQL; los eventos de auditoría son de solo lectura en la interfaz.

La suite de integración del backend solo se ejecuta si `DB_TEST_URL` apunta explícitamente a una base desechable cuyo nombre termina en `clinica_test`. No apuntes esa variable a la base de datos operativa.
