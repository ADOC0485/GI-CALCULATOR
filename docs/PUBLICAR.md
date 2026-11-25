# Publicar versiones y actualizaciones

Hay dos formas de hacer llegar cambios:

- **Parche** (lo normal para arreglos pequeños): llega solo a las apps
  instaladas, sin GitHub ni reinstalar. Ver [Parches](#parches-sin-reinstalar).
- **Versión nueva**: un APK en GitHub que se instala encima. Hace falta para
  cambios de Android, imágenes y archivos de `assets/`, o paquetes nuevos.

Las apps instaladas consultan al abrirse la última versión publicada en
[GitHub Releases](https://github.com/ADOC0485/GI-CALCULATOR/releases). Si es más
nueva que la suya, muestran «Hay una versión nueva» y el botón **Actualizar**
descarga el APK. Android lo instala **encima** de la app y se conservan los
datos, siempre que el APK esté firmado con **la misma llave** que la versión
instalada.

## Llave de firma (una sola vez)

1. Crea la llave **fuera del repositorio** (te pedirá una contraseña y unos
   datos; la contraseña solo la sabes tú):

   ```powershell
   & "C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe" -genkeypair -v -keystore "$env:USERPROFILE\gi-calculator-release.jks" -keyalg RSA -keysize 2048 -validity 10000 -alias gi-calculator
   ```

2. Copia `android/key.properties.example` como `android/key.properties` y
   pon tus contraseñas. Ese archivo y los `.jks` están en `.gitignore`: nunca
   se suben.
3. Guarda una copia de seguridad del `.jks` y de las contraseñas (por ejemplo
   en un gestor de contraseñas). Si se pierden, las apps instaladas ya no
   podrán actualizarse: habría que desinstalar y perder los datos.

Un APK compilado sin `key.properties` usa la llave de depuración: sirve para
probar, pero no puede actualizar la app publicada.

## Publicar una versión

1. Sube la versión en `pubspec.yaml` (`version: X.Y.Z+N`, con `N` siempre
   mayor que la anterior) y en `lib/features/updates/app_update.dart`
   (`appVersion = 'X.Y.Z'`). Una prueba comprueba que coincidan.
2. Commit y push.
3. Ejecuta:

   ```powershell
   powershell -ExecutionPolicy Bypass -File tool\publish_release.ps1 -Notas "Qué cambió"
   ```

El script comprueba la llave, la versión y que todo esté subido, compila el
APK firmado **con Shorebird** (para que luego pueda recibir parches), lo
registra en Shorebird y crea la versión `vX.Y.Z` en GitHub con el APK adjunto.
Después compila la versión de Windows también con Shorebird y adjunta
`GenshinProgressPlanner-vX.Y.Z-windows.zip` (la carpeta completa con
`GenshinProgressPlanner.exe`). En PC, la app avisa de versiones nuevas y baja
ese .zip; para instalarlo se reemplaza la carpeta anterior y los datos se
conservan.
Shorebird puede preguntar si quieres continuar: responde `y`. El
repositorio es público: cualquiera puede ver y descargar cada versión.

Los datos del juego (personajes, armas, materiales) no necesitan una versión
nueva: se actualizan con «Actualizar desde internet» en el catálogo.

## Parches sin reinstalar

Usa [Shorebird](https://shorebird.dev). Una vez por computadora:

1. Instala Shorebird:

   ```powershell
   git clone -b stable https://github.com/shorebirdtech/shorebird.git "$HOME\.shorebird"
   [Environment]::SetEnvironmentVariable("Path", [Environment]::GetEnvironmentVariable("Path", "User") + ";$HOME\.shorebird\bin", "User")
   ```

2. Abre una PowerShell nueva y entra con tu cuenta: `shorebird login`.

`shorebird.yaml` ya conecta el proyecto con la app en Shorebird; su `app_id`
no es secreto.

Para mandar un parche:

1. Haz el cambio **sin** tocar la versión de `pubspec.yaml`.
2. Commit y push.
3. Ejecuta:

   ```powershell
   powershell -ExecutionPolicy Bypass -File tool\publish_patch.ps1
   ```

Las apps lo descargan solas al abrirse y lo usan la siguiente vez que se
abren; también aparece un aviso «Se descargó una mejora». En Ajustes se ve
el número de parche, y «Buscar actualizaciones» también busca parches.

Un parche **no** puede cambiar imágenes ni archivos de `assets/`, nada de
`android/` (ícono, permisos) ni paquetes con código nativo: Shorebird lo
detecta y se detiene. Para eso publica una versión nueva. Si un parche sale
mal, se puede retirar desde [console.shorebird.dev](https://console.shorebird.dev).

Solo reciben parches las apps instaladas desde una versión compilada con
Shorebird: en Android desde la v0.3.0, y en Windows desde la v0.3.1. El
script crea el parche para cada plataforma que tenga esa versión. Las
copias de PC anteriores a la v0.3.1 se compilaron sin Shorebird y nunca
reciben parches: hay que pasarlas una vez al .zip de la v0.3.1.
