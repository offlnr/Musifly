# API privada de musifly

Preparada para el bucket R2 existente `musifly`. No cambia la visibilidad del bucket ni modifica sus archivos. La app mantiene nombres genéricos: Canción 1… y Álbum 1 para la biblioteca completa.

## Publicación

El servicio ya está publicado; consulta DEPLOYMENT.md para los resultados de verificación. Los pasos siguientes sirven para volver a publicarlo o configurar otro dispositivo.

1. Desde esta carpeta: `npm ci`.
2. Autenticar con `npx wrangler login` y verificar la cuenta con `npx wrangler whoami`.
3. Guardar dos valores aleatorios diferentes, de al menos 32 bytes, mediante `npx wrangler secret put APP_TOKEN` y `npx wrangler secret put SIGNING_KEY`. Ambos comandos solicitan el valor de forma interactiva. No guardar valores en el repositorio ni enviarlos al chat.
4. Publicar con `npm run deploy` y anotar la URL HTTPS del Worker. Si la cuenta contiene varios perfiles, definir `account_id` en wrangler.jsonc antes de publicar.
5. En el iPhone: CANCIONES → SYS/NODO_07 → BIBLIOTECA R2. Introducir la URL del Worker y APP_TOKEN. No introducir SIGNING_KEY ni claves API de Cloudflare.

APP_TOKEN es una credencial de acceso personal a la biblioteca completa. La app la guarda en Keychain, solo para este dispositivo. SIGNING_KEY permanece exclusivamente como secreto del Worker y firma enlaces de lectura válidos durante seis horas. Quien posea un enlace puede leer esa canción durante su vigencia. No es un servicio multiusuario; para compartir la aplicación se necesita autenticación por usuario y revocación individual.

Los enlaces se firman y sirven mediante el propio Worker; no son URLs S3 presignadas. El Worker usa un binding de R2 y no necesita Access Key ID ni Secret Access Key de R2. Su código solo expone operaciones de lectura. La observabilidad está desactivada para no registrar enlaces firmados en los logs de solicitudes.

## Rutas

- GET /catalog: requiere Authorization: Bearer APP_TOKEN; devuelve objetos de audio y un cursor. La app recorre todas las páginas, aunque una página no contenga audio.
- GET /play?key=…: autenticada; entrega un enlace temporal para una canción existente.
- GET o HEAD /media?key=…&expires=…&signature=…: valida firma y vencimiento; admite HTTP Range, devuelve 206/416 cuando corresponde.
- No permite subir, borrar ni editar objetos.

Se aceptan extensiones mp3, m4a, aac, wav, flac, aif, aiff y caf. La reproducción depende del códec que soporte iOS. Las duraciones se obtienen al cargar cada canción. El espectro sigue siendo ilustrativo, no un análisis FFT del audio. La reproducción en segundo plano, controles de pantalla bloqueada y descarga offline no están incluidos en esta entrega.

## Verificación

`npm test` verifica rechazo sin credenciales, filtrado de archivos, firmas, manipulación de enlaces, vencimiento, lectura parcial, HEAD y rechazo de escrituras. Utiliza un bucket simulado; no prueba acceso al bucket real.

Verificaciones en el bucket real y en el dispositivo: consulta DEPLOYMENT.md.
