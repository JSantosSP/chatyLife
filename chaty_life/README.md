# ChatyLife

Una aplicación de chat tipo WhatsApp simplificada construida con Flutter y Firebase.

## Características

- 🔐 **Autenticación completa**: Registro, inicio de sesión y recuperación de contraseña
- 👥 **Gestión de contactos**: Buscar usuarios y agregar contactos
- 💬 **Chat en tiempo real**: Mensajería instantánea con Firestore
- 📝 **Mensajes de texto**: Envía y recibe mensajes de texto
- 😀 **Emojis**: Selector de emojis integrado
- 🖼️ **Imágenes**: Envío de imágenes con almacenamiento temporal y descarga local
- 🎤 **Audios**: Graba y envía mensajes de audio
- 🔔 **Notificaciones push**: Notificaciones cuando recibes mensajes nuevos
- 🔒 **Seguridad**: Reglas de Firestore y Storage configuradas

## Tecnologías

- **Flutter** - Framework de desarrollo móvil
- **Firebase Auth** - Autenticación de usuarios
- **Cloud Firestore** - Base de datos en tiempo real
- **ImgBB API / Base64** - Almacenamiento gratuito de archivos (sin Firebase Storage)
- **Firebase Cloud Messaging** - Notificaciones push
- **Firebase Functions** - Borrado automático de archivos temporales

## Requisitos

- Flutter SDK 3.10.3 o superior
- Cuenta de Firebase
- Android Studio / Xcode para desarrollo

## Instalación

1. Clona el repositorio
2. Instala las dependencias:
```bash
flutter pub get
```

3. Configura Firebase (ver `README_SETUP.md` para instrucciones detalladas)

4. Ejecuta la aplicación:
```bash
flutter run
```

## Configuración

Consulta `README_SETUP.md` para instrucciones detalladas sobre:
- Configuración de Firebase
- Reglas de Firestore
- Configuración de notificaciones push
- Permisos de Android e iOS
- Almacenamiento gratuito (ver `STORAGE_FREE.md`)

## Estructura del Proyecto

```
lib/
├── models/          # Modelos de datos
├── services/        # Servicios de Firebase
├── screens/         # Pantallas de la aplicación
└── widgets/         # Componentes reutilizables
```

## Funcionalidades MVP

✅ Autenticación completa
✅ Búsqueda y gestión de contactos
✅ Chat individual en tiempo real
✅ Mensajes de texto, emojis, imágenes y audios
✅ Notificaciones push
✅ Almacenamiento temporal de imágenes
✅ Descarga local de imágenes y audios
✅ Reglas de seguridad

## Licencia

Este proyecto es de código abierto y está disponible bajo la licencia MIT.

## Autor

Desarrollado como plantilla base para aplicaciones de chat.
