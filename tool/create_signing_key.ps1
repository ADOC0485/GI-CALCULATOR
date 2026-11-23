<#
Crea la llave de firma de la app con una contraseña aleatoria.

Uso (desde la carpeta del proyecto, una sola vez):
  powershell -ExecutionPolicy Bypass -File tool\create_signing_key.ps1

Genera una contraseña segura, crea el almacén de claves fuera del
repositorio y escribe android\key.properties (que nunca se sube a GitHub).
La contraseña no se muestra en pantalla: queda guardada en key.properties.
Haz copia de seguridad de ese archivo y del .jks.
#>
param(
  [string]$Almacen = (Join-Path $env:USERPROFILE 'gi-calculator-release.jks'),
  [string]$Alias = 'gi-calculator'
)
$ErrorActionPreference = 'Stop'
Set-Location (Split-Path $PSScriptRoot -Parent)

if (Test-Path $Almacen) { throw "Ya existe $Almacen. No lo sobrescribo: es tu llave." }
if ((Test-Path android\key.properties) -and
    -not (Select-String -Path android\key.properties -Pattern 'ESCRIBE_TU_CONTRASENA' -Quiet)) {
  throw 'android\key.properties ya tiene una contraseña. No lo sobrescribo.'
}
$keytool = 'C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe'
if (-not (Test-Path $keytool)) { throw "No encontré keytool en $keytool." }

# 32 letras y números al azar (sin símbolos, para evitar problemas de escape).
$letras = [char[]]'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789'
$bytes = New-Object byte[] 32
[System.Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($bytes)
$clave = -join ($bytes | ForEach-Object { $letras[$_ % $letras.Length] })

# keytool prints progress on stderr; Windows PowerShell would treat that as
# an error under 'Stop', so relax it just for this call and check the result.
$ErrorActionPreference = 'Continue'
& $keytool -genkeypair -keystore $Almacen -alias $Alias -keyalg RSA -keysize 2048 `
  -validity 10000 -storepass $clave -keypass $clave `
  -dname 'CN=GI Calculator, OU=Genshin Progress Planner, C=CO' 2>$null | Out-Null
$codigo = $LASTEXITCODE
$ErrorActionPreference = 'Stop'
if ($codigo -ne 0 -or -not (Test-Path $Almacen)) { throw 'keytool no pudo crear la llave.' }

$ruta = $Almacen -replace '\\', '/'
@"
# Release signing key. This file is in .gitignore: it is never uploaded.
# Back up this file and the .jks together; without them the published app
# cannot be updated.
storeFile=$ruta
storePassword=$clave
keyAlias=$Alias
keyPassword=$clave
"@ | Set-Content android\key.properties -Encoding ascii

Write-Host "Llave creada: $Almacen"
Write-Host 'Contraseña guardada en android\key.properties (no se muestra aquí).'
