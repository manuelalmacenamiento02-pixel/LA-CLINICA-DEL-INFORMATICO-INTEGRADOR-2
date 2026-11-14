[CmdletBinding()]
param(
    [string]$PostgresBin = 'C:\Program Files\PostgreSQL\18\bin',
    [string]$DatabaseHost = 'localhost',
    [int]$DatabasePort = 5432,
    [string]$DatabaseAdmin = 'postgres'
)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$psql = Join-Path $PostgresBin 'psql.exe'
if (-not (Test-Path -LiteralPath $psql)) { throw "No se encontró psql: $psql" }
function Read-Secret([string]$Prompt) {
    $secret = Read-Host $Prompt -AsSecureString
    $pointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secret)
    try { return [Runtime.InteropServices.Marshal]::PtrToStringBSTR($pointer) }
    finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($pointer) }
}
$oldPgPassword = $env:PGPASSWORD
$oldAppPassword = $env:CLINICA_APP_PASSWORD
try {
    $env:PGPASSWORD = Read-Secret "Contraseña del administrador PostgreSQL ($DatabaseAdmin)"
    $env:CLINICA_APP_PASSWORD = Read-Secret 'Contraseña para clinica_app (si ya existe, usa su contraseña actual)'
    if ($env:CLINICA_APP_PASSWORD.Length -lt 10) { throw 'Usa una contraseña de al menos 10 caracteres.' }
    & $psql -w -h $DatabaseHost -p $DatabasePort -U $DatabaseAdmin -d postgres -f (Join-Path $projectRoot 'database\provision.sql')
    if ($LASTEXITCODE -ne 0) { throw 'No se pudo preparar la base de datos.' }
    $env:PGPASSWORD = $env:CLINICA_APP_PASSWORD
    & $psql -w -h $DatabaseHost -p $DatabasePort -U clinica_app -d clinica_informatica -c 'SELECT current_database(), current_user;'
    if ($LASTEXITCODE -ne 0) { throw 'La conexión de clinica_app falló. No se cambian contraseñas de roles existentes.' }
    Write-Host 'Base de datos preparada. Ejecuta scripts\Start-Backend.ps1 para aplicar las migraciones.'
} finally {
    $env:PGPASSWORD = $oldPgPassword
    $env:CLINICA_APP_PASSWORD = $oldAppPassword
}
