# NexusRide

Aplicación Flutter de seguridad para ciclistas. Combina ubicación, rutas,
conexión BLE con el módulo del casco, contactos de emergencia y alertas.

## Requisitos

- Flutter 3.44.0 o posterior y Dart 3.11.0 o posterior, según
  `pubspec.yaml`.
- Android Studio/SDK para Android.
- Xcode y CocoaPods para iOS.
- Proyectos configurados en Supabase, Firebase y Google Maps.
- La app está dirigida a Android y iOS. Las carpetas Web, Linux, macOS y
  Windows son scaffolding de Flutter; BLE, permisos y ejecución en segundo
  plano no están implementados para esas plataformas.

## Configuración local

1. Instala dependencias: `flutter pub get`.
2. Copia `.env.example.json` como `.env.dev.json` y completa tus valores. Mantén `.env.dev.json` y `.env.prod.json` con `SUPABASE_URL`,
   `SUPABASE_PUBLISHABLE_KEY`, `GOOGLE_MAPS_KEY_ANDROID` y `GOOGLE_MAPS_KEY_IOS`. Son
   archivos locales ignorados por Git.
3. Ejecuta `python3 tool/sync_ios_maps_keys.py` para generar la configuración
   nativa de Google Maps para Debug y Release. Los archivos generados también
   están ignorados por Git.
4. Android usa el identificador `com.iangea.nexusride2025`. Registra ese ID como
   app Android en Firebase y descarga el `google-services.json` correspondiente
   a `android/app/google-services.json`. Este archivo no se distribuye con la copia pública.
5. Descarga de Firebase un `ios/Runner/GoogleService-Info.plist` generado para
   `com.iangea.nexusride2025`. Este archivo no se distribuye con la copia pública.
6. Genera `lib/firebase_options.dart` para tu propio proyecto con FlutterFire CLI (`flutterfire configure`). El archivo original fue excluido de la publicación.
7. Ejecuta en un dispositivo o emulador:

   ```sh
   flutter run --dart-define-from-file=.env.dev.json
   ```

El mapa usa la última ubicación del teléfono, marca esa posición y centra la
cámara conforme llegan nuevas coordenadas. Android recibe su clave desde los
dart-defines; iOS la lee desde `Info.plist`, resuelta desde los xcconfig
generados con los archivos de entorno.

## BLE en segundo plano

En Android, el servicio BLE se configura al iniciar la app. Al conectar un
módulo, guarda su dirección de forma segura y vuelve a intentar la conexión
cada 10 segundos si se pierde. Al abrir Inicio, tras conceder permisos, la app
pide al servicio recuperar el módulo guardado.

En iOS, el escaneo y la conexión siguen ejecutándose en primer plano. iOS no
mantiene un isolate Dart de ejecución continua; para recuperación BLE nativa en
segundo plano se requiere implementar restauración de estado de CoreBluetooth.

## Alertas de emergencia

La Edge Function activa `notify-emergency` valida el JWT y confirma que el
incidente pertenezca al usuario antes de enviar SMS mediante Twilio. Configura
los secretos `TWILIO_ACCOUNT_SID`, `TWILIO_AUTH_TOKEN` y `TWILIO_FROM_NUMBER` en
Supabase. La función también usa las variables estándar de Supabase, incluida
`SUPABASE_SERVICE_ROLE_KEY`; esa clave solo se usa en el servidor y no debe
incluirse en la app.

Las funciones heredadas `bright-action` y `update-notification-status` están
retiradas: requieren JWT y responden HTTP 410. La app debe usar
`notify-emergency`. Revisa `supabase/config.toml` y despliega desde
`supabase/functions` para mantener sincronizadas la configuración y las
versiones remotas.

La app conserva el incidente y muestra un estado de error si el registro, la
cancelación o el envío fallan. Los estados individuales de SMS se muestran en
la pantalla de confirmación.

## Base de datos y retención

El esquema actual está versionado en `supabase/migrations`. La migración de
baseline registra las tablas, relaciones, índices, RLS y trigger de creación de
perfil; la siguiente endurece las políticas, restringe las funciones de
trigger y programa la retención. No ejecutes una migración manual en producción
sin crear primero su archivo local y revisar el SQL.

Supabase conserva las ubicaciones durante 90 días desde `recorded_at` (hora de
captura), y los incidentes y sus notificaciones durante un año. Los trabajos
se ejecutan diariamente en UTC; las notificaciones se eliminan en cascada con
su incidente. Las ubicaciones pendientes en Hive CE siguen almacenadas localmente
hasta que se sincronicen. Si se sube una ubicación con más de 90 días, puede
ser eliminada en la próxima ejecución diaria de retención.

El almacenamiento local de ubicaciones pendientes usa Hive CE. La migración
conserva la caja `pending_locations`, el tipo 0 y los mismos números de campo
del adaptador; Hive CE documenta compatibilidad con el formato en disco de Hive
v2. El alta de usuario crea `profiles` mediante el trigger `on_auth_user_created`;
el cliente no debe insertar un segundo perfil. Google OAuth y la protección
contra contraseñas filtradas se configuran en Auth del Dashboard y deben
verificarse allí por entorno. Google OAuth permanece pendiente: registra las
credenciales de cliente en Google y Supabase antes de habilitarlo. La protección
contra contraseñas filtradas requiere el plan Supabase Pro o superior.

La app valida `SUPABASE_URL`, `SUPABASE_PUBLISHABLE_KEY` y la clave Maps de la
plataforma al arrancar. Si falta un dart-define, muestra un error de
configuración y no inicializa los servicios.

## Builds

### Android Debug

`flutter run --dart-define-from-file=.env.dev.json`

### Android Release

1. Genera o selecciona el keystore de distribución y guárdalo fuera del control
   de versiones.
2. Copia `android/key.properties.example` a `android/key.properties` y completa
   la ruta del keystore, su contraseña, el alias y la contraseña de la clave.
3. Ejecuta:

   ```sh
   flutter build appbundle --release --dart-define-from-file=.env.prod.json
   ```

Una tarea Release ya no usa la firma Debug. Si falta `android/key.properties`,
Gradle detiene el build con un mensaje; los builds Debug siguen disponibles.

### iOS Release

Configura la firma de Apple en Xcode, instala/actualiza las dependencias iOS con
`flutter pub get` y `pod install` desde `ios`, genera los xcconfig de Google
Maps y confirma que `GoogleService-Info.plist` corresponda al bundle ID configurado.
Después ejecuta:

```sh
flutter build ios --release --dart-define-from-file=.env.prod.json
```

## Pruebas

`flutter test` ejecuta pruebas locales de configuración obligatoria,
persistencia de ubicaciones en Hive CE, distancia geográfica, acumulación de
ruta BLE y conversión de contactos de emergencia desde/hacia JSON. BLE físico,
OAuth, notificaciones push, Google Maps nativo, sincronización contra Supabase
y SMS requieren pruebas de integración con dispositivo y servicios
configurados.

## Estructura del código

- `lib/core`: inicialización, constantes y servicios compartidos.
- `lib/features`: pantallas, estado y modelos por funcionalidad.
- `lib/shared`: router, tema y widgets reutilizables.
- `supabase/functions`: funciones Edge mantenidas junto al cliente.

## Publicación de portafolio

Esta copia excluye entornos reales, configuración Firebase, firma, cachés, bases locales y artefactos generados. Se publica el código; no se despliegan servicios ni se envían SMS. Los ejemplos de las pruebas son sintéticos.

Antes de usarla con personas reales se requiere una revisión del backend desplegado: RLS por propietario, autorización negativa, límites de envío e idempotencia de SMS, consentimiento de contactos y política de retención. El análisis local no certifica esos controles en producción.
