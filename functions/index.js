const { onDocumentUpdated } = require("firebase-functions/v2/firestore");
const admin = require("firebase-admin");

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
