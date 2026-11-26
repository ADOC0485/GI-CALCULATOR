<#
Envía un parche (arreglo pequeño) a las apps ya instaladas, sin reinstalar,
en Android y en Windows (desde la v0.3.1; la v0.3.0 solo existe en Android).

Uso (desde la carpeta del proyecto):
  powershell -ExecutionPolicy Bypass -File tool\publish_patch.ps1

Las apps lo descargan solas al abrirse y lo usan la siguiente vez que se
abren. Sirve para cambios en el código Dart (pantallas, textos, cálculos).
NO sirve, y hace falta una versión nueva con tool\publish_release.ps1, para:
  - imágenes o archivos de assets/ (nombres-es.json, reglas, logo),
  - el ícono, permisos o cualquier cosa de android/,
  - paquetes nuevos de pubspec.yaml con código nativo.
Shorebird avisa y se detiene si detecta alguno de esos cambios.

No cambies la versión de pubspec.yaml: el parche es para la versión que ya
tienen instalada (la última publicada en GitHub).
#>
param(
  [string]$Repositorio = 'ADOC0485/GI-CALCULATOR'
)
$ErrorActionPreference = 'Continue'
Set-Location (Split-Path $PSScriptRoot -Parent)

$pubspec = Get-Content pubspec.yaml -Raw
if ($pubspec -notmatch '(?m)^version:\s*(\d+\.\d+\.\d+)\+(\d+)') {
  throw 'No encontré "version: X.Y.Z+N" en pubspec.yaml.'
}
$version = $Matches[1]
$codigo = $Matches[2]
$ultima = gh release view --repo $Repositorio --json tagName --jq .tagName 2>$null
if ($LASTEXITCODE -ne 0 -or -not $ultima) { throw 'No se pudo consultar la última versión en GitHub.' }
if ($ultima -ne "v$version") {
  throw "pubspec.yaml dice $version pero la última versión publicada es $ultima. Un parche va sobre la versión publicada: deja pubspec.yaml como estaba, o publica una versión nueva con tool\publish_release.ps1."
}
if (git status --porcelain) {
  throw 'Hay cambios sin commit. Haz commit y push antes de publicar el parche.'
}
$rama = git branch --show-current
git fetch origin $rama 2>$null | Out-Null
if ($LASTEXITCODE -ne 0) { throw 'No se pudo consultar GitHub (git fetch).' }
if ((git rev-parse HEAD) -ne (git rev-parse "origin/$rama")) {
  throw "La rama $rama no está subida. Haz git push antes de publicar."
}

$shorebird = (Get-Command shorebird -ErrorAction SilentlyContinue).Source
if (-not $shorebird) { $shorebird = "$HOME\.shorebird\bin\shorebird.bat" }
if (-not (Test-Path $shorebird)) {
  throw 'No encontré Shorebird. Instálalo e inicia sesión (ver docs\PUBLICAR.md).'
}

# Windows releases exist from 0.3.1 on; earlier ones are Android only.
$plataformas = @('android')
if ([version]$version -ge [version]'0.3.1') { $plataformas += 'windows' }
foreach ($plataforma in $plataformas) {
  Write-Host "Creando parche de $plataforma para la v$version ($version+$codigo)..."
  # Same icon set as the release (built with --no-tree-shake-icons), or
  # Shorebird sees the icon font as a changed asset and refuses the patch.
  & $shorebird patch $plataforma --release-version "$version+$codigo" --track stable --no-tree-shake-icons
  if ($LASTEXITCODE -ne 0) { throw "No se pudo crear el parche de $plataforma." }
}
Write-Host 'Listo: las apps lo descargan al abrirse y lo usan la siguiente vez que se abren.'
