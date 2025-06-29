import 'package:cloud_firestore/cloud_firestore.dart';
class NotificationResponse {
  List<NotificationModel>? notifications;

  NotificationResponse({
    this.notifications,
  });

  NotificationResponse.fromJson(Map<String, dynamic> json) {
    if (json['notifications'] != null) {
      notifications = <NotificationModel>[];
      json['notifications'].forEach((v) {
        notifications!.add(new NotificationModel.fromMap(v));
      });
    }
  }
}
class NotificationModel {
  DateTime? createdAt;
  Map<String, dynamic>? data;
  String? title;
  String? message;
  String? status;
  List<String>? fcmTokens;
  String? userId;
  String? type;

  NotificationModel({
    this.createdAt,
    this.data,
    required this.title,
    required this.message,
    this.status,
    this.fcmTokens,
    this.userId,
    this.type,
  });

  factory NotificationModel.fromMap(Map<String, dynamic> map) {
    List<String> tokens = <String>[];
    if (map['fcmToken'] != null) {
      final List<dynamic> tkns = map['fcmToken'];
      for (dynamic tkn in tkns){
        tokens.add(tkn.toString());
      }
    }
    return NotificationModel(
      createdAt: map['createdAt'] != null
          ? (map['createdAt'] as Timestamp).toDate()
          : null,
      data: map['data'],
      title: map['title'] ?? 'Notiication',
      message: map['message'] ?? map['body'] ?? '',
      status: map['status'],
      fcmTokens: tokens,
      userId: map['userId'],
      type: map['type'],
      // branchName is assigned later by the provider, not read from the map
    );
  }
}
