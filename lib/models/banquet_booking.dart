// lib/models/banquet_booking.dart

import 'package:cloud_firestore/cloud_firestore.dart';

// All Hive-related code has been removed.

class BanquetBooking { // No longer extends HiveObject
  DateTime date;
  String hallName;
  String slotLabel;
  String customerName;
  String phone;
  String? callbackComment;
  int pax;
  double amount;
  String menu;
  double totalAmount;
  double remainingAmount;
  String comments;
  DateTime? callbackTime;
  bool isDraft;

  BanquetBooking({
    required this.date,
    required this.hallName,
    required this.slotLabel,
    required this.customerName,
    required this.phone,
    required this.pax,
    required this.amount,
    required this.menu,
    required this.totalAmount,
    required this.remainingAmount,
    required this.comments,
    this.callbackTime,
    required this.isDraft,
    this.callbackComment
  });

  /// Convert to Firestore map
  Map<String, dynamic> toMap() {
    return {
      'date': Timestamp.fromDate(date),
      'hallName': hallName,
      'slotLabel': slotLabel,
      'customerName': customerName,
      'phone': phone,
      'callbackComment': callbackComment,
      'pax': pax,
      'amount': amount,
      'menu': menu,
      'totalAmount': totalAmount,
      'remainingAmount': remainingAmount,
      'comments': comments,
      'callbackTime': callbackTime != null ? Timestamp.fromDate(callbackTime!) : null,
      'isDraft': isDraft,
    };
  }

  /// Create from Firestore map
  factory BanquetBooking.fromMap(Map<String, dynamic> map) {
    return BanquetBooking(
      date: (map['date'] as Timestamp).toDate(),
      hallName: map['hallName'] ?? '',
      slotLabel: map['slotLabel'] ?? '',
      customerName: map['customerName'] ?? '',
      phone: map['phone'] ?? '',
      callbackComment: map['callbackComment'] ?? '',
      pax: map['pax'] ?? 0,
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      menu: map['menu'] ?? '',
      totalAmount: (map['totalAmount'] as num?)?.toDouble() ?? 0.0,
      remainingAmount: (map['remainingAmount'] as num?)?.toDouble() ?? 0.0,
      comments: map['comments'] ?? '',
      callbackTime: map['callbackTime'] != null ? (map['callbackTime'] as Timestamp).toDate() : null,
      isDraft: map['isDraft'] ?? false,
    );
  }
}
