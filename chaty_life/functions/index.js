/**
 * Cloud Functions para Firebase - ChatyLife
 * Envío automático de notificaciones push cuando se crea un nuevo mensaje
 * 
 * Compatible con plan Blaze
 * Usando Cloud Functions v1 (más simple, no requiere Eventarc)
 */

const functions = require("firebase-functions");
const admin = require("firebase-admin");

// Inicializar Firebase Admin SDK
admin.initializeApp();

/**
 * Función que se ejecuta automáticamente cuando se crea un nuevo mensaje
 * Envía una notificación push al usuario receptor
 * 
 * Trigger: chats/{chatId}/messages/{messageId} onCreate
 */
exports.sendMessageNotification = functions.firestore
    .document("chats/{chatId}/messages/{messageId}")
    .onCreate(async (snap, context) => {
      const message = snap.data();
      const chatId = context.params.chatId;

      if (!message) {
        console.log("Mensaje vacío, no se enviará notificación");
        return null;
      }

      const receiverId = message.receiverId;

      if (!receiverId) {
        console.log("No hay receptor especificado");
        return null;
      }

      try {
        // Obtener información del usuario receptor
        const receiverDoc = await admin.firestore()
            .collection("users")
            .doc(receiverId)
            .get();

        if (!receiverDoc.exists) {
          console.log(`Usuario receptor ${receiverId} no encontrado`);
          return null;
        }

        const receiverData = receiverDoc.data();
        const fcmToken = receiverData && receiverData.fcmToken;

        if (!fcmToken) {
          console.log(`Usuario ${receiverId} no tiene token FCM`);
          return null;
        }

        // Obtener información del usuario emisor
        const senderDoc = await admin.firestore()
            .collection("users")
            .doc(message.senderId)
            .get();

        const senderData = senderDoc.exists ? senderDoc.data() : null;
        const senderName = (senderData && senderData.username) || "Alguien";

        // Preparar el contenido de la notificación según el tipo de mensaje
        let notificationTitle = senderName;
        let notificationBody = message.content || "";

        if (message.type === "image") {
          notificationBody = "📷 Envió una imagen";
        } else if (message.type === "audio") {
          notificationBody = "🎤 Envió un audio";
        } else if (message.type === "emoji") {
          notificationBody = message.content || "😊";
        }

        // Crear el payload de la notificación
        const payload = {
          notification: {
            title: notificationTitle,
            body: notificationBody,
            sound: "default",
          },
          data: {
            chatId: chatId,
            senderId: message.senderId,
            type: "message",
          },
          token: fcmToken,
        };

        // Enviar la notificación usando Firebase Cloud Messaging
        const response = await admin.messaging().send(payload);

        console.log("✅ Notificación enviada exitosamente", {
          chatId: chatId,
          receiverId: receiverId,
          messageId: response,
        });

        return response;
      } catch (error) {
        console.error("❌ Error al enviar notificación", {
          error: error.message,
          chatId: chatId,
          receiverId: receiverId,
        });
        return null;
      }
    });
