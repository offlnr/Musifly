# Publicación

Worker: `sono-private-music`
Bucket privado: `musifly`
Endpoint: https://sono-private-music.m-lizana003.workers.dev

Secretos configurados: `APP_TOKEN` para iPhone, `ANDROID_TOKEN` adicional para Android y `SIGNING_KEY` para enlaces temporales. Los valores están excluidos del repositorio.

El servicio permite consultar el catálogo con paginación, pedir enlaces de reproducción y leer audio con rangos HTTP. No permite modificar archivos ni hace público el bucket.

Validación: pruebas automatizadas de ambas credenciales, rechazo de peticiones no autorizadas y rangos HTTP. La clave adicional Android también se comprobó contra el catálogo y una lectura parcial de audio reales.

Para publicar: `npm ci`, `npm test` y `npx wrangler deploy`. Se requiere una sesión autorizada en Cloudflare. No reemplazar los secretos existentes para añadir un dispositivo.
