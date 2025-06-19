// lib/models/customer.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class Customer {
  int token;
  String name;
  String phone;
  int pax;
  DateTime registeredAt;
  DateTime? calledAt;
  int children;
  String? operator;
  String? waiterName;
  bool isCalled; // --- NEW FIELD to track if the customer has been called ---

  Customer({
    required this.token,
    required this.name,
    required this.phone,
    required this.pax,
    required this.registeredAt,
    this.calledAt,
    this.children = 0,
    this.operator,
    this.waiterName,
    this.isCalled = false, // --- ADDED TO CONSTRUCTOR ---
  });

  Map<String, dynamic> toMap() {
    return {
      'token': token,
      'name': name,
      'phone': phone,
      'pax': pax,
      'registeredAt': registeredAt,
      'calledAt': calledAt,
      'children': children,
      'operator': operator,
      'waiterName': waiterName,
      'isCalled': isCalled, // --- ADDED TO MAP ---
    };
  }

  factory Customer.fromMap(Map<String, dynamic> map) {
    return Customer(
      token: map['token'] ?? 0,
      name: map['name'] ?? '',
      phone: map['phone'] ?? '',
      pax: map['pax'] ?? 0,
      registeredAt: (map['registeredAt'] as Timestamp).toDate(),
      calledAt: map['calledAt'] != null ? (map['calledAt'] as Timestamp).toDate() : null,
      children: map['children'] ?? 0,
      operator: map['operator'],
      waiterName: map['waiterName'],
      isCalled: map['isCalled'] ?? false, // --- ADDED FROM MAP ---
    );
  }
}