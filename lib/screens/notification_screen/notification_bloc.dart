import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:token_manager/screens/notification_screen/notification_event.dart';
import 'package:token_manager/screens/notification_screen/notification_model.dart';
import 'package:token_manager/screens/notification_screen/notification_state.dart';

class NotificationBloc extends Bloc<NotificationEvent, NotificationState> {
  NotificationBloc() : super(NotificationState()) {
    on<SetFcmTokenEvent>(_setFcmTokenEvent);
    on<GetNotificationEvent>(_getNotificationEvent);
    on<SendNotificationToAdminAfterTimer>(_sendNotificationToAdminAfterTimer);
  }

  final FirebaseFirestore _fireStore = FirebaseFirestore.instance;
  String? fcmToken;
  List<NotificationModel>? notifications;
  Future<void> _setFcmTokenEvent(
      SetFcmTokenEvent event, Emitter<NotificationState> emit) async {
    fcmToken = event.fcmToken;
  }

  Future<void> _getNotificationEvent(
      GetNotificationEvent event, Emitter<NotificationState> emit) async {
    final querySnapshot = await _fireStore
        .collection('notifications')
        //.where('fcmTokem', isEqualTo: fcmToken)
        .get();
    final notificationsList =
        querySnapshot.docs.map((doc) => doc.data()).toList();
    print('notifications = $notificationsList');
    final NotificationResponse response =
        NotificationResponse.fromJson({'notifications': notificationsList});
    notifications = <NotificationModel>[];
    if (response.notifications != null && response.notifications!.isNotEmpty) {
      for (final NotificationModel model in response.notifications!) {
        final List<String>? tokens = model.fcmTokens;
        if (tokens != null && tokens.isNotEmpty) {
          for (final String tkn in tokens) {
            if (tkn == fcmToken!) {
              notifications!.add(model);
            }
          }
        }
      }
    }
    // notifications = response.notifications;
    emit(NotificationSuccessState());
  }

  Future<void> _sendNotificationToAdminAfterTimer(
      SendNotificationToAdminAfterTimer event,
      Emitter<NotificationState> emit) async {
    if (fcmToken == null) {
      print('token not available');
      return;
    }
    final querySnapshot = await _fireStore
        .collection('users')
        .where('adminDisplayEnabled', isEqualTo: true)
        .get();

    final admins = querySnapshot.docs.map((doc) => doc.data()).toList();
    List<String> adminTokens = [];

    for (var doc in querySnapshot.docs) {
      final data = doc.data();
      final tokens = data['fcmToken'];

      if (tokens != null) {
        if (tokens is String) {
          adminTokens.add(tokens);
        } else if (tokens is List) {
          // If you store multiple tokens as list, add all
          adminTokens.addAll(List<String>.from(tokens));
        }
      }
    }

    print('Admin FCM tokens: $adminTokens');
    await _fireStore.collection('notifications').add({
      'title': 'Callback Comment Missing',
      'message': '"You forgot to leave a comment after your call.',
      'type': 'missedComment',
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
      'fcmToken': adminTokens,
      'data': {'bookingId': event.bookingId},
      'userId': FirebaseAuth.instance.currentUser!.uid,
    });
  }
}
