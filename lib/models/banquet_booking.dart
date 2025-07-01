// lib/models/banquet_booking.dart

import 'package:cloud_firestore/cloud_firestore.dart';

// All Hive-related code has been removed.

class BanquetBooking {
  // No longer extends HiveObject
  DateTime date;
  List<Map<String, String>> hallSlots;
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

  BanquetBooking(
      {required this.date,
      required this.hallSlots,
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
      this.callbackComment});

  /// Convert to Firestore map
  Map<String, dynamic> toMap() {
    return {
      'date': Timestamp.fromDate(date),
      'hallSlots': hallSlots,
      'customerName': customerName,
      'phone': phone,
      'callbackComment': callbackComment,
      'pax': pax,
      'amount': amount,
      'menu': menu,
      'totalAmount': totalAmount,
      'remainingAmount': remainingAmount,
      'comments': comments,
      'callbackTime':
          callbackTime != null ? Timestamp.fromDate(callbackTime!) : null,
      'isDraft': isDraft,
    };
  }

  /// Create from Firestore map
  factory BanquetBooking.fromMap(Map<String, dynamic> map) {
    List<Map<String, String>> hallSlots;

    if (map['hallSlots'] != null) {
      // New format: List of {hallName, slotLabel} pairs
      hallSlots = List<Map<String, String>>.from((map['hallSlots'] as List)
          .map((item) => Map<String, String>.from(item)));
    } else if (map['hallNames'] != null && map['slotLabel'] != null) {
      // Backward compatibility: Convert hallNames + slotLabel to hallSlots
      List<String> hallNames = List<String>.from(map['hallNames']);
      String slotLabel = map['slotLabel'];
      hallSlots = hallNames
          .map((hallName) => {
                'hallName': hallName,
                'slotLabel': slotLabel,
              })
          .toList();
    } else if (map['hallName'] != null && map['slotLabel'] != null) {
      // Backward compatibility: Single hall + slot
      hallSlots = [
        {
          'hallName': map['hallName'],
          'slotLabel': map['slotLabel'],
        }
      ];
    } else {
      hallSlots = [];
    }

    return BanquetBooking(
      date: (map['date'] as Timestamp).toDate(),
      hallSlots: hallSlots,
      customerName: map['customerName'] ?? '',
      phone: map['phone'] ?? '',
      callbackComment: map['callbackComment'] ?? '',
      pax: map['pax'] ?? 0,
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      menu: map['menu'] ?? '',
      totalAmount: (map['totalAmount'] as num?)?.toDouble() ?? 0.0,
      remainingAmount: (map['remainingAmount'] as num?)?.toDouble() ?? 0.0,
      comments: map['comments'] ?? '',
      callbackTime: map['callbackTime'] != null
          ? (map['callbackTime'] as Timestamp).toDate()
          : null,
      isDraft: map['isDraft'] ?? false,
    );
  }

  /// Get the first hall name for backward compatibility
  String get hallName =>
      hallSlots.isNotEmpty ? hallSlots.first['hallName'] ?? '' : '';

  /// Get the first slot label for backward compatibility
  String get slotLabel =>
      hallSlots.isNotEmpty ? hallSlots.first['slotLabel'] ?? '' : '';

  /// Get all hall names
  List<String> get hallNames =>
      hallSlots.map((hs) => hs['hallName'] ?? '').toList();

  /// Get all slot labels
  List<String> get slotLabels =>
      hallSlots.map((hs) => hs['slotLabel'] ?? '').toList();

  /// Check if a specific hall+slot combination is in this booking
  bool containsHallSlot(String hallName, String slotLabel) {
    final contains = hallSlots.any(
        (hs) => hs['hallName'] == hallName && hs['slotLabel'] == slotLabel);

    print('DEBUG: containsHallSlot($hallName, $slotLabel) = $contains');
    print('DEBUG: This booking has hallSlots: $hallSlots');

    return contains;
  }
}
