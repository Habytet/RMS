const { onDocumentUpdated } = require("firebase-functions/v2/firestore");
const admin = require("firebase-admin");
const { onSchedule } = require("firebase-functions/v2/scheduler");

admin.initializeApp(); // ✅ FULL firebase-admin initialized

exports.sendProfileUpdateNotification = onDocumentUpdated("users/{userId}", async (event) => {
  const after = event.data.after.data();
  const fcmToken = after.fcmToken;

  if (!fcmToken) {
    console.log("No FCM token found for user.");
    return;
  }

  const payload = {
    notification: {
      title: "Profile Updated",
      body: `Hi ${after.name}, your profile was updated.`,
    },
  };

  try {
    const response = await admin.messaging().send({
                                                    token: fcmToken,
                                                    notification: {
                                                      title: 'Profile Updated',
                                                      body: `Hi ${after.name}, your profile was updated.`
                                                    },
                                                    data: {
                                                      customKey: 'customValue' // optional
                                                    }
                                                  });
    console.log("FCM response:", response);
  } catch (error) {
    console.error("Error sending FCM notification:", error);
  }
});


exports.sendMissedCommentNotifications = onSchedule("every 1 minutes", async (event) => {
  const now = admin.firestore.Timestamp.now();
  const fifteenMinutesAgo = admin.firestore.Timestamp.fromMillis(now.toMillis() - 15 * 60 * 1000);

  const snapshot = await admin.firestore()
    .collection("notifications")
    .where("createdAt", "<=", fifteenMinutesAgo)
    .where("status", "==", "pending")
    .where("type", "==", "missedComment")
    .get();

  const batch = admin.firestore().batch();

  for (const doc of snapshot.docs) {
    const data = doc.data();

    if (!data.fcmToken || !Array.isArray(data.fcmToken) || data.fcmToken.length === 0) {
      console.log("No valid FCM tokens found for", doc.id);
      continue;
    }

    const messagePayload = {
      notification: {
        title: "Callback Comment Missing",
        body: "You forgot to leave a comment after your call.",
      },
      data: {
        bookingId: data.bookingId || "",
        userId: data.userId || "",
      }
    };

    try {
      const response = await admin.messaging().sendMulticast({
        tokens: data.fcmToken,
        ...messagePayload,
      });

      console.log(`✅ Notification sent to ${response.successCount} tokens for doc ${doc.id}`);

      if (response.failureCount > 0) {
        response.responses.forEach((resp, idx) => {
          if (!resp.success) {
            console.error(`Failed to send to token ${data.fcmToken[idx]}:`, resp.error);
          }
        });
      }

      batch.update(doc.ref, { status: "sent" });

    } catch (error) {
      console.error("❌ Failed to send notifications:", error);
    }
  }

  await batch.commit();
});