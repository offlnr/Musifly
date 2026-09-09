# Validación — 9 de septiembre de 2026

APK de desarrollo compilado y firma APK v2 verificada. Pruebas ejecutadas en emulador Android 15 ARM64, pantalla de referencia 393 × 852.

Cuatro pruebas automatizadas distintas completadas:

1. Abrir un álbum, cambiar de pestaña, agregar a playlist mediante pulsación larga, abrir/cerrar la playlist, comprobar persistencia y cifrado con Android Keystore.
2. Reproducir WAV de prueba, recibir datos reales del espectro, mostrar controles, buscar a 10 segundos y comprobar avance de reproducción tras ir a la pantalla de inicio de Android.
3. Catálogo R2 con paginación, autenticación Bearer, nombres con +/#/espacios, validación del dominio de enlaces firmados y rechazo de credenciales inválidas, contra servidor HTTPS local de prueba.
4. Leer título, artista, álbum, número y duración de metadata FLAC, y comprobar que la caché evita repetir peticiones.

Capturas revisadas visualmente para corregir el recorte de carátulas y visibilidad de las barras del sistema. El patrón de prueba usa una onda sinusoidal: una sola banda dominante en el espectro es el resultado esperado.

Pendiente de validación física: conexión al bucket privado con la clave del usuario, auriculares Bluetooth/AirPods reales y comportamiento del ahorro de batería del fabricante del teléfono. No se incluyeron secretos ni canciones de prueba en el APK distribuido. La app requiere configurar su conexión una vez.

La versión iOS no se modificó al crear esta versión Android.
