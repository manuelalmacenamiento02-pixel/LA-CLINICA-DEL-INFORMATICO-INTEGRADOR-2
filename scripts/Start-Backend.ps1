[CmdletBinding()]
param(
    [string]$DatabaseHost = 'localhost',
    [int]$DatabasePort = 5432,
    [string]$DatabaseName = 'clinica_informatica',
    [string]$DatabaseUser = 'postgres',
    [string]$AdminUsername = 'admin',
    [switch]$ActualizarClave,
    [switch]$ActualizarClaveGemini
)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$passwordFile = Join-Path $projectRoot '.local\database-password.dpapi'
$geminiKeyFile = Join-Path $projectRoot '.local\gemini-api-key.dpapi'
$javaHomes = @()
if ($env:JAVA_HOME) { $javaHomes += $env:JAVA_HOME }
$javaHomes += Get-ChildItem -Path 'C:\Program Files\Eclipse Adoptium' -Directory -Filter 'jdk-25*' -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName
$localJdks = Join-Path $env:LOCALAPPDATA 'Programs\Temurin\jdk-25\PFiles64\Eclipse Adoptium'
$javaHomes += Get-ChildItem -Path $localJdks -Directory -Filter 'jdk-25*' -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName
$javaHome = $javaHomes | Where-Object {
    (Test-Path -LiteralPath (Join-Path $_ 'bin\java.exe')) -and
    (Test-Path -LiteralPath (Join-Path $_ 'bin\javac.exe')) -and
    (Select-String -Path (Join-Path $_ 'release') -Pattern '^JAVA_VERSION="25(\.|")' -Quiet)
} | Select-Object -First 1
if (-not $javaHome) {
    throw 'Java 25 is required. Install the bundled JDK from INSTALAR\jdk-25_windows-x64_bin.msi, then run this script again.'
}
function Convert-SecureStringToPlainText([Security.SecureString]$Secret) {
    $pointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($Secret)
    try { return [Runtime.InteropServices.Marshal]::PtrToStringBSTR($pointer) }
    finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($pointer) }
}
function Get-DatabasePassword([string]$Path, [bool]$ForcePrompt) {
    if (-not $ForcePrompt -and (Test-Path -LiteralPath $Path)) {
        try {
            $encrypted = [IO.File]::ReadAllText($Path).Trim()
            return ConvertTo-SecureString -String $encrypted
        } catch {
            throw "No se pudo descifrar la clave guardada. Vuelve a guardarla ejecutando el script con -ActualizarClave."
        }
    }

    $secret = Read-Host "Contraseña PostgreSQL de $DatabaseUser" -AsSecureString
    if ($secret.Length -eq 0) { throw 'La contraseña de PostgreSQL no puede estar vacía.' }
    $directory = Split-Path -Parent $Path
    if (-not (Test-Path -LiteralPath $directory)) {
        New-Item -ItemType Directory -Path $directory | Out-Null
    }
    $encrypted = ConvertFrom-SecureString -SecureString $secret
    [IO.File]::WriteAllText($Path, $encrypted)
    Write-Host 'Contraseña guardada cifrada para este usuario de Windows.'
    return $secret
}
function Get-GeminiApiKey([string]$Path, [bool]$ForcePrompt) {
    if (-not $ForcePrompt) {
        $inheritedKey = [Environment]::GetEnvironmentVariable('GEMINI_API_KEY', 'Process')
        if (-not [string]::IsNullOrWhiteSpace($inheritedKey)) { return $inheritedKey }

        if (Test-Path -LiteralPath $Path) {
            try {
                $encrypted = [IO.File]::ReadAllText($Path).Trim()
                $secret = ConvertTo-SecureString -String $encrypted
                try { return Convert-SecureStringToPlainText $secret }
                finally { $secret.Dispose() }
            } catch {
                throw 'No se pudo descifrar la clave Gemini guardada. Vuelve a guardarla con -ActualizarClaveGemini.'
            }
        }
    }

    $secureKey = Read-Host 'Clave API de Gemini (Enter para continuar sin habilitar IA)' -AsSecureString
    if ($secureKey.Length -eq 0) {
        if ($ForcePrompt -and (Test-Path -LiteralPath $Path)) {
            Remove-Item -LiteralPath $Path
        }
        return ''
    }
    $directory = Split-Path -Parent $Path
    if (-not (Test-Path -LiteralPath $directory)) {
        New-Item -ItemType Directory -Path $directory | Out-Null
    }
    $encrypted = ConvertFrom-SecureString -SecureString $secureKey
    [IO.File]::WriteAllText($Path, $encrypted)
    try { $plainKey = Convert-SecureStringToPlainText $secureKey }
    finally { $secureKey.Dispose() }
    Write-Host 'Clave Gemini guardada cifrada para este usuario de Windows.'
    return $plainKey
}
$oldValues = @{}
foreach ($key in @('DB_URL','DB_USER','DB_PASSWORD','ADMIN_USERNAME','ADMIN_PASSWORD','GEMINI_API_KEY','JAVA_HOME','PATH')) {
    $oldValues[$key] = [Environment]::GetEnvironmentVariable($key, 'Process')
}
$databasePassword = $null
$geminiApiKey = $null
try {
    $env:JAVA_HOME = $javaHome
    $env:PATH = "$(Join-Path $javaHome 'bin');$($oldValues['PATH'])"
    $env:DB_URL = "jdbc:postgresql://${DatabaseHost}:${DatabasePort}/${DatabaseName}"
    $env:DB_USER = $DatabaseUser
    $databasePassword = Get-DatabasePassword -Path $passwordFile -ForcePrompt:$ActualizarClave.IsPresent
    $env:DB_PASSWORD = Convert-SecureStringToPlainText $databasePassword
    $env:ADMIN_USERNAME = $AdminUsername
    $geminiApiKey = Get-GeminiApiKey -Path $geminiKeyFile -ForcePrompt:$ActualizarClaveGemini.IsPresent
    $env:GEMINI_API_KEY = $geminiApiKey
    Push-Location (Join-Path $projectRoot 'backend')
    try {
        & .\mvnw.cmd spring-boot:run
        if ($LASTEXITCODE -ne 0) {
            throw 'El backend no pudo iniciar. Si el error indica "password authentication failed", actualiza la clave guardada ejecutando el script con -ActualizarClave.'
        }
    } finally { Pop-Location }
} finally {
    if ($databasePassword) { $databasePassword.Dispose() }
    $geminiApiKey = $null
    foreach ($key in $oldValues.Keys) { [Environment]::SetEnvironmentVariable($key, $oldValues[$key], 'Process') }
}
