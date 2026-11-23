# Publicar versiones y actualizaciones

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
APK firmado y crea la versión `vX.Y.Z` en GitHub con el APK adjunto. El
repositorio es público: cualquiera puede ver y descargar cada versión.

Los datos del juego (personajes, armas, materiales) no necesitan una versión
nueva: se actualizan con «Actualizar desde internet» en el catálogo.
