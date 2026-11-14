[CmdletBinding()]
param(
    [string]$PostgresBin = 'C:\Program Files\PostgreSQL\18\bin',
    [string]$DatabaseHost = 'localhost',
    [int]$DatabasePort = 5432,
    [string]$DatabaseName = 'clinica_informatica',
    [string]$DatabaseUser = 'clinica_app'
)
$ErrorActionPreference = 'Stop'
$backupDirectory = Join-Path (Split-Path -Parent $PSScriptRoot) 'database\backups'
New-Item -ItemType Directory -Force -Path $backupDirectory | Out-Null
$backupPath = Join-Path $backupDirectory ("clinica-" + (Get-Date -Format 'yyyyMMdd-HHmmss-fff') + '.dump')
$oldPassword = $env:PGPASSWORD
$pointer = [IntPtr]::Zero
try {
    $secret = Read-Host "Contraseña PostgreSQL de $DatabaseUser" -AsSecureString
    $pointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secret)
    $env:PGPASSWORD = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($pointer)
    & (Join-Path $PostgresBin 'pg_dump.exe') -w -h $DatabaseHost -p $DatabasePort -U $DatabaseUser -d $DatabaseName --format=custom --file=$backupPath
    if ($LASTEXITCODE -ne 0) { throw 'El respaldo falló; no uses el archivo parcial.' }
    Write-Host "Respaldo: $backupPath"
    Get-FileHash -LiteralPath $backupPath -Algorithm SHA256
} finally {
    $env:PGPASSWORD = $oldPassword
    if ($pointer -ne [IntPtr]::Zero) { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($pointer) }
}
