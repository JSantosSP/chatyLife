/// Configuración para el servicio de almacenamiento
/// 
/// Opciones gratuitas:
/// 1. ImgBB API (recomendado para imágenes) - https://api.imgbb.com
///    - Gratis hasta 32MB por imagen
///    - Obtén tu API key en: https://api.imgbb.com/
/// 
/// 2. Base64 (fallback) - Almacena directamente en Firestore
///    - Limitado a ~1MB por documento
///    - No requiere configuración adicional

class StorageConfig {
  // Configuración de ImgBB (opcional pero recomendado)
  // Obtén tu API key gratuita en: https://api.imgbb.com/
  static const String imgbbApiKey = '8288116ff9e146a1ce0e1a59a887f431'; // Deja vacío para usar Base64
  
  // Usar ImgBB si hay API key configurada
  static bool get useImgBB => imgbbApiKey.isNotEmpty;
  
  // Límite de tamaño para Base64 (en bytes)
  static const int maxBase64Size = 800 * 1024; // 800KB
}
