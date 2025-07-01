// lib/models/banquet_booking.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:token_manager/models/hall.dart';

// All Hive-related code has been removed.

class BanquetBooking {
  DateTime date;
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
  List<HallInfo> hallInfos;

  BanquetBooking({
    required this.date,
    required this.customerName,
    required this.phone,
    this.callbackComment,
    required this.pax,
    required this.amount,
    required this.menu,
    required this.totalAmount,
    required this.remainingAmount,
    required this.comments,
    this.callbackTime,
    required this.isDraft,
    required this.hallInfos,
  });

  factory BanquetBooking.fromJson(Map<String, dynamic> json) {
    return BanquetBooking(
        date: json['date'] != null
            ? (json['date'] as Timestamp).toDate()
            : DateTime.now(),
      //date: DateTime.parse(json['date']),
      customerName: json['customerName'],
      phone: json['phone'],
      callbackComment: json['callbackComment'],
      pax: json['pax'],
      amount: (json['amount'] as num).toDouble(),
      menu: json['menu'],
      totalAmount: (json['totalAmount'] as num).toDouble(),
      remainingAmount: (json['remainingAmount'] as num).toDouble(),
      comments: json['comments'],
      callbackTime: json['callbackTime'] != null
          ? (json['date'] as Timestamp).toDate()
          : null,
      isDraft: json['isDraft'],
      hallInfos: json['hallInfos'] != null ? (json['hallInfos'] as List)
          .map((h) => HallInfo.fromJson(h))
          .toList() : <HallInfo>[],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'date': Timestamp.fromDate(date),
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
      'hallInfos': hallInfos.map((h) => h.toJson()).toList(),
    };
  }
}

