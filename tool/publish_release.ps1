<#
Publica una versión nueva de la app en GitHub Releases.

Uso (desde la carpeta del proyecto):
  powershell -ExecutionPolicy Bypass -File tool\publish_release.ps1 -Notas "Ícono nuevo y avisos de actualización"

Antes de ejecutarlo:
  1. Sube la versión en pubspec.yaml (version: X.Y.Z+N, con N siempre mayor)
     y en lib/features/updates/app_update.dart (appVersion = 'X.Y.Z').
  2. Haz commit y push de esos cambios.
  3. Ten android/key.properties con tu llave de firma (ver docs/PUBLICAR.md).

Las apps instaladas verán el aviso «Hay una versión nueva» al abrirse.
#>
param(
  [Parameter(Mandatory = $true)][string]$Notas,
  [string]$Repositorio = 'ADOC0485/GI-CALCULATOR'
)
$ErrorActionPreference = 'Stop'
Set-Location (Split-Path $PSScriptRoot -Parent)

$pubspec = Get-Content pubspec.yaml -Raw
if ($pubspec -notmatch '(?m)^version:\s*(\d+\.\d+\.\d+)\+(\d+)') {
  throw 'No encontré "version: X.Y.Z+N" en pubspec.yaml.'
}
$version = $Matches[1]
$codigo = $Matches[2]
$constante = Get-Content lib\features\updates\app_update.dart -Raw
if ($constante -notmatch "appVersion = '$([regex]::Escape($version))'") {
  throw "appVersion en lib/features/updates/app_update.dart no es $version. Ponlo igual que en pubspec.yaml."
}
if (-not (Test-Path android\key.properties)) {
  throw 'Falta android\key.properties: sin tu llave de firma las apps instaladas no podrían actualizarse. Mira docs\PUBLICAR.md.'
}
if (git status --porcelain) {
  throw 'Hay cambios sin commit. Haz commit y push antes de publicar.'
}
$rama = git branch --show-current
git fetch origin $rama 2>$null
if ((git rev-parse HEAD) -ne (git rev-parse "origin/$rama")) {
  throw "La rama $rama no está subida. Haz git push antes de publicar."
}
$etiqueta = "v$version"
gh release view $etiqueta --repo $Repositorio 2>$null | Out-Null
if ($LASTEXITCODE -eq 0) {
  throw "La versión $etiqueta ya está publicada. Sube el número de versión."
}

Write-Host "Compilando $etiqueta (código $codigo)..."
flutter build apk --release
if ($LASTEXITCODE -ne 0) { throw 'Falló la compilación del APK.' }

New-Item -ItemType Directory -Force build\release | Out-Null
$apk = "build\release\GenshinProgressPlanner-$etiqueta.apk"
Copy-Item build\app\outputs\flutter-apk\app-release.apk $apk -Force

Write-Host "Publicando $etiqueta en $Repositorio..."
gh release create $etiqueta $apk --repo $Repositorio --target $rama --title $etiqueta --notes $Notas --latest
if ($LASTEXITCODE -ne 0) { throw 'No se pudo crear la versión en GitHub.' }
Write-Host "Listo: https://github.com/$Repositorio/releases/tag/$etiqueta"
