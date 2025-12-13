import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';
import 'firestore_service.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirestoreService _firestoreService = FirestoreService();

  User? get currentUser => _auth.currentUser;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<UserModel?> signUp({
    required String email,
    required String password,
    required String username,
  }) async {
    try {
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (userCredential.user != null) {
        final userModel = UserModel(
          uid: userCredential.user!.uid,
          username: username,
          createdAt: DateTime.now(),
        );

        await _firestoreService.createUser(userModel);
        return userModel;
      }
      return null;
    } on FirebaseAuthException catch (e) {
      // Manejar errores específicos de Firebase Auth
      String errorMessage;
      switch (e.code) {
        case 'weak-password':
          errorMessage = 'La contraseña es muy débil';
          break;
        case 'email-already-in-use':
          errorMessage = 'Ya existe una cuenta con este email';
          break;
        case 'invalid-email':
          errorMessage = 'Email inválido';
          break;
        case 'operation-not-allowed':
          errorMessage = 'Operación no permitida';
          break;
        default:
          errorMessage = 'Error al registrar: ${e.message ?? 'Error desconocido'}';
      }
      throw Exception(errorMessage);
    } catch (e) {
      // Manejar otros tipos de errores
      if (e is Exception) {
        rethrow;
      }
      throw Exception('Error al registrar: ${e.toString()}');
    }
  }

  Future<UserModel?> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (userCredential.user != null) {
        return await _firestoreService.getUser(userCredential.user!.uid);
      }
      return null;
    } on FirebaseAuthException catch (e) {
      // Manejar errores específicos de Firebase Auth
      String errorMessage;
      switch (e.code) {
        case 'user-not-found':
          errorMessage = 'No existe una cuenta con este email';
          break;
        case 'wrong-password':
          errorMessage = 'Contraseña incorrecta';
          break;
        case 'invalid-email':
          errorMessage = 'Email inválido';
          break;
        case 'user-disabled':
          errorMessage = 'Esta cuenta ha sido deshabilitada';
          break;
        case 'too-many-requests':
          errorMessage = 'Demasiados intentos fallidos. Intenta más tarde';
          break;
        case 'operation-not-allowed':
          errorMessage = 'Operación no permitida';
          break;
        default:
          errorMessage = 'Error al iniciar sesión: ${e.message ?? 'Error desconocido'}';
      }
      throw Exception(errorMessage);
    } catch (e) {
      // Manejar otros tipos de errores
      if (e is Exception) {
        rethrow;
      }
      throw Exception('Error al iniciar sesión: ${e.toString()}');
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      // Manejar errores específicos de Firebase Auth
      String errorMessage;
      switch (e.code) {
        case 'user-not-found':
          errorMessage = 'No existe una cuenta con este email';
          break;
        case 'invalid-email':
          errorMessage = 'Email inválido';
          break;
        default:
          errorMessage = 'Error al enviar email de recuperación: ${e.message ?? 'Error desconocido'}';
      }
      throw Exception(errorMessage);
    } catch (e) {
      // Manejar otros tipos de errores
      if (e is Exception) {
        rethrow;
      }
      throw Exception('Error al enviar email de recuperación: ${e.toString()}');
    }
  }

  Future<UserModel?> getUserData() async {
    if (currentUser != null) {
      return await _firestoreService.getUser(currentUser!.uid);
    }
    return null;
  }
}



