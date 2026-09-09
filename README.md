# Musifly

Aplicación de música con estética CRT para iOS y Android, conectada a una biblioteca privada en Cloudflare R2.

## Proyectos

- `ios/SonoCRT.xcodeproj`: app SwiftUI, nombre visible Musifly.
- `android/`: app Kotlin y Jetpack Compose, con Gradle Wrapper.
- `backend/`: Worker que lista el catálogo y emite enlaces de audio firmados.

## Funciones

Carátulas y etiquetas, búsqueda, playlists locales, navegación por gestos, miniplayer persistente, títulos deslizantes, búsqueda temporal, reproducción en segundo plano, controles multimedia y espectro de audio real.

Las preferencias de ecualizador/calidad/red son de demostración. No hay descargas offline ni sincronización de playlists entre dispositivos.

## Configuración privada

Configurar en Cloudflare los secretos `APP_TOKEN`, `ANDROID_TOKEN` (opcional) y `SIGNING_KEY`. El bucket permanece privado. Las claves se introducen en cada app y se guardan en Keychain/Android Keystore. No se incluyen secretos en el código ni en los binarios.

## Compilación

Abrir el proyecto iOS en Xcode y configurar el equipo de firma. Para Android, usar JDK 17 y SDK 35; ejecutar `./gradlew assembleDebug` desde `android/`. Para el Worker, ejecutar `npm ci` y `npm test` desde `backend/`.
