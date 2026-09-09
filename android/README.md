# Musifly para Android

App nativa en Kotlin y Jetpack Compose. Android 8.0 (API 26) o posterior.

## Instalación

Instala `Musifly.apk` en el teléfono y permite la instalación desde la aplicación que uses para abrirlo. Es un APK de desarrollo firmado para instalación directa, no una publicación en Google Play.

En CANCIONES → SYS/NODO_07 → BIBLIOTECA R2 introduce la clave de tu biblioteca. El dominio del Worker ya viene indicado. La clave es la de acceso a Musifly, **no** las credenciales de Cloudflare. El APK no contiene secretos.

La conexión se cifra con una clave de Android Keystore. Desinstalar la app elimina la conexión y las playlists locales. No desinstales para actualizar: instala el nuevo APK firmado con la misma clave encima del anterior.

## Funciones

- Diseño CRT: fondo oscuro, verdes, monoespaciada, bordes rectos, scanlines y viñeta sin degradados.
- INICIO, BUSCAR, PLAYLISTS y CANCIONES, con deslizamiento horizontal.
- Álbumes, artistas, búsqueda y carátulas; lectura de etiquetas FLAC/Vorbis y otros formatos mediante Android.
- API privada R2, catálogo paginado, enlaces de reproducción firmados renovados al abrir la fuente, caracteres especiales en los nombres y caché de metadatos.
- Mini player fijo con su propio espacio; barra inferior que cierra los submenús al tocar una pestaña.
- Reproductor con carátula grande, título deslizante, barra arrastrable, anterior/play/pausa/siguiente grandes, shuffle y repetición.
- Espectro real de 32 bandas sobre el 45 % inferior de la carátula, respuesta agresiva y dibujo sincronizado con los fotogramas. No usa el micrófono.
- Reproducción en segundo plano, notificación multimedia, pantalla bloqueada, audio focus y pausa al desconectar auriculares.
- Crear playlists y agregar canciones mediante pulsación larga; persistencia local sin duplicados.
- Gesto desde el borde izquierdo y gesto de Android para volver; deslizar hacia abajo sobre la carátula cierra el reproductor.
- Indicador de teléfono/auriculares, según dispositivos de audio expuestos por Android. No requiere funciones exclusivas de Apple.
- Configuración CRT persistente. Calidad, ecualizador y preferencias de red conservan el carácter de demostración de la versión iOS; no son efectos de audio ni descargas offline.

Las playlists de Android y de iPhone son independientes. La biblioteca se actualiza al iniciar la app o pulsar ACTUALIZAR BIBLIOTECA; no hay un monitor continuo del bucket.

## Proyecto

- `data/`: modelos, almacenamiento cifrado, playlists, API y metadatos.
- `playback/`: servicio Media3, controlador y analizador de audio PCM.
- `ui/`: tema, componentes y pantallas Compose.
- `app/src/androidTest/`: pruebas de navegación, persistencia, cifrado, reproducción, búsqueda temporal y audio en segundo plano.

Abrir esta carpeta en Android Studio, con JDK 17 y SDK 35. Ejecutar `./gradlew assembleDebug` para crear el APK o `./gradlew connectedDebugAndroidTest` con un emulador/dispositivo conectado.

Los formatos disponibles dependen del decodificador Android: FLAC, MP3, AAC/M4A y WAV son los principales. Archivos como CAF/AIFF pueden necesitar conversión, según el dispositivo; la API original permite esas extensiones pero la app iOS no garantiza que todos sus códecs internos sean reproducibles tampoco.
