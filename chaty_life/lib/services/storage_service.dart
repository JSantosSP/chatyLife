import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:gal/gal.dart';
import 'package:permission_handler/permission_handler.dart';
import '../config/storage_config.dart';

/// Servicio de almacenamiento usando alternativas gratuitas
/// - ImgBB API para imágenes (gratis, hasta 32MB)
/// - Base64 para imágenes pequeñas y audios (almacenado en Firestore)
class StorageService {
  
  /// Subir imagen usando ImgBB API (gratuita) o Base64 como fallback
  Future<String> uploadTemporaryImage(File imageFile, String chatId) async {
    try {
      // Leer el archivo como bytes
      final bytes = await imageFile.readAsBytes();
      
      // Si no hay API key configurada o el archivo es muy pequeño, usar Base64 directamente
      if (!StorageConfig.useImgBB || bytes.length < 100 * 1024) {
        return await _uploadImageAsBase64(imageFile);
      }
      
      // Intentar subir a ImgBB
      try {
        final base64Image = base64Encode(bytes);
        final uri = Uri.parse('https://api.imgbb.com/1/upload');
        final response = await http.post(
          uri,
          body: {
            'key': StorageConfig.imgbbApiKey,
            'image': base64Image,
          },
        ).timeout(const Duration(seconds: 30));

        if (response.statusCode == 200) {
          final jsonResponse = jsonDecode(response.body);
          if (jsonResponse['success'] == true) {
            // ImgBB devuelve la URL de la imagen
            return jsonResponse['data']['url'] as String;
          } else {
            throw Exception('Error en ImgBB: ${jsonResponse['error']?['message'] ?? 'Unknown error'}');
          }
        } else {
          throw Exception('Error HTTP: ${response.statusCode}');
        }
      } catch (e) {
        // Si falla ImgBB, usar Base64 como fallback
        print('ImgBB falló, usando Base64: $e');
        return await _uploadImageAsBase64(imageFile);
      }
    } catch (e) {
      throw Exception('Error al subir imagen: ${e.toString()}');
    }
  }

  /// Fallback: Subir imagen como Base64 directamente a Firestore
  /// Limitado a ~1MB por documento de Firestore
  Future<String> _uploadImageAsBase64(File imageFile) async {
    try {
      final bytes = await imageFile.readAsBytes();
      
      // Verificar tamaño (Firestore tiene límite de 1MB)
      if (bytes.length > StorageConfig.maxBase64Size) {
        throw Exception(
          'La imagen es demasiado grande para Base64 (${(bytes.length / 1024).toStringAsFixed(0)}KB). '
          'Máximo: ${(StorageConfig.maxBase64Size / 1024).toStringAsFixed(0)}KB. '
          'Configura ImgBB API key para imágenes más grandes.'
        );
      }
      
      final base64Image = base64Encode(bytes);
      
      // Retornar como data URI (se almacena en Firestore)
      return 'data:image/jpeg;base64,$base64Image';
    } catch (e) {
      throw Exception('Error al procesar imagen: ${e.toString()}');
    }
  }

  /// Subir audio como Base64 (almacenado en Firestore)
  /// Nota: Firestore tiene límite de 1MB por documento
  Future<String> uploadTemporaryAudio(File audioFile, String chatId) async {
    try {
      // Leer el archivo como bytes
      final bytes = await audioFile.readAsBytes();
      
      // Verificar tamaño (Firestore tiene límite de 1MB)
      if (bytes.length > StorageConfig.maxBase64Size) {
        throw Exception(
          'El archivo de audio es demasiado grande (${(bytes.length / 1024).toStringAsFixed(0)}KB). '
          'Máximo: ${(StorageConfig.maxBase64Size / 1024).toStringAsFixed(0)}KB. '
          'Graba un audio más corto.'
        );
      }
      
      // Codificar a Base64
      final base64Audio = base64Encode(bytes);
      
      // Retornar como data URI (se almacena en Firestore)
      return 'data:audio/m4a;base64,$base64Audio';
    } catch (e) {
      throw Exception('Error al procesar audio: ${e.toString()}');
    }
  }

  /// Descargar y guardar imagen localmente desde URL o Base64
  Future<String?> downloadAndSaveImage(String imageUrl, String chatId, String messageId) async {
    try {
      // Solicitar permisos
      if (await Permission.storage.request().isGranted ||
          await Permission.photos.request().isGranted) {
        
        Uint8List? bytes;
        
        // Si es una data URI (Base64), decodificar directamente
        if (imageUrl.startsWith('data:image')) {
          final base64String = imageUrl.split(',')[1];
          bytes = base64Decode(base64String);
        } else {
          // Si es una URL normal (ImgBB), descargar
          final response = await http.get(Uri.parse(imageUrl)).timeout(
            const Duration(seconds: 30),
          );
          if (response.statusCode == 200) {
            bytes = response.bodyBytes;
          } else {
            throw Exception('Error al descargar imagen: ${response.statusCode}');
          }
        }
        
        if (bytes != null) {
          // Guardar en galería usando gal
          try {
            await Gal.putImageBytes(bytes);
            // Guardar también en el directorio de documentos como respaldo
            final appDir = await getApplicationDocumentsDirectory();
            final imageDir = Directory('${appDir.path}/ChatyLife/images');
            
            if (!await imageDir.exists()) {
              await imageDir.create(recursive: true);
            }
            
            final tempFile = File('${imageDir.path}/ChatyLife_${chatId}_$messageId.jpg');
            await tempFile.writeAsBytes(bytes);
            
            return tempFile.path;
          } catch (e) {
            // Si falla gal, guardar solo en el directorio de documentos
            final appDir = await getApplicationDocumentsDirectory();
            final imageDir = Directory('${appDir.path}/ChatyLife/images');
            
            if (!await imageDir.exists()) {
              await imageDir.create(recursive: true);
            }
            
            final tempFile = File('${imageDir.path}/ChatyLife_${chatId}_$messageId.jpg');
            await tempFile.writeAsBytes(bytes);
            
            return tempFile.path;
          }
        }
      }
      return null;
    } catch (e) {
      throw Exception('Error al descargar imagen: ${e.toString()}');
    }
  }

  /// Descargar y guardar audio localmente desde Base64
  Future<String?> downloadAndSaveAudio(String audioUrl, String chatId, String messageId) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final audioDir = Directory('${appDir.path}/ChatyLife/audios/$chatId');
      
      if (!await audioDir.exists()) {
        await audioDir.create(recursive: true);
      }
      
      Uint8List? bytes;
      
      // Si es una data URI (Base64), decodificar directamente
      if (audioUrl.startsWith('data:audio')) {
        final base64String = audioUrl.split(',')[1];
        bytes = base64Decode(base64String);
      } else {
        // Si es una URL normal, descargar (no debería pasar con la implementación actual)
        final response = await http.get(Uri.parse(audioUrl)).timeout(
          const Duration(seconds: 30),
        );
        if (response.statusCode == 200) {
          bytes = response.bodyBytes;
        } else {
          throw Exception('Error al descargar audio: ${response.statusCode}');
        }
      }
      
      if (bytes != null) {
        final file = File('${audioDir.path}/$messageId.m4a');
        await file.writeAsBytes(bytes);
        return file.path;
      }
      
      return null;
    } catch (e) {
      throw Exception('Error al descargar audio: ${e.toString()}');
    }
  }

  /// Eliminar archivo temporal
  /// Nota: Con Base64, los datos se eliminan automáticamente cuando se elimina el mensaje de Firestore
  /// Con ImgBB, las imágenes se eliminan automáticamente después de un tiempo
  Future<void> deleteTemporaryFile(String fileUrl) async {
    // No es necesario eliminar manualmente:
    // - Base64: Se elimina con el mensaje en Firestore
    // - ImgBB: Se elimina automáticamente después de un tiempo
    // Si necesitas eliminar de ImgBB, puedes usar su API de eliminación
  }
}
