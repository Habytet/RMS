class NotificationEvent {}

class SetFcmTokenEvent extends NotificationEvent {
  SetFcmTokenEvent({required this.fcmToken});
  final String fcmToken;
}
class GetNotificationEvent extends NotificationEvent {}

class SendNotificationToAdminAfterTimer extends NotificationEvent {
  SendNotificationToAdminAfterTimer({required this.bookingId, required this.body});
  final String bookingId;
  final String body;
}
