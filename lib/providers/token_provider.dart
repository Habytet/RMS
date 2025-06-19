// lib/providers/token_provider.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/customer.dart';

class TokenProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String branchId;

  late final Query<Map<String, dynamic>> _queueCol;
  late final CollectionReference<Map<String, dynamic>> _completedCol;
  late final DocumentReference<Map<String, dynamic>> _settingsDoc;

  int _nextToken = 1;
  int? _nowServing;
  List<Customer> _queue = [];
  List<Customer> _allHistory = [];
  List<int> _availableTables = [];

  int get nextToken => _nextToken;
  int? get nowServing => _nowServing;
  List<Customer> get queue => _queue;
  List<Customer> get allHistory => _allHistory;
  List<int> get availableTables => List.unmodifiable(_availableTables);

  TokenProvider({required this.branchId}) {
    _queueCol = _firestore.collection('branches/$branchId/queue').orderBy('token');
    _completedCol = _firestore.collection('branches/$branchId/completed');
    _settingsDoc = _firestore.collection('branches').doc(branchId);
    _init();
  }

  void _init() {
    _queueCol.snapshots().listen((snapshot) {
      _queue = snapshot.docs.map((doc) => Customer.fromMap(doc.data())).toList();
      notifyListeners();
    });
    _settingsDoc.snapshots().listen((docSnapshot) {
      final data = docSnapshot.data();
      if (data != null) {
        _nowServing = data['nowServing'] as int?;
        _nextToken = data['nextToken'] as int? ?? 1;
        _availableTables = List<int>.from(data['availableTables'] ?? []);
        notifyListeners();
      }
    });
    _completedCol.orderBy('registeredAt', descending: true).limit(20).snapshots().listen((snapshot) {
      _allHistory = snapshot.docs.map((doc) => Customer.fromMap(doc.data())).toList();
      notifyListeners();
    });
  }

  Future<List<Customer>> fetchHistoryByDateRange(DateTimeRange range) async {
    final start = Timestamp.fromDate(range.start);
    final end = Timestamp.fromDate(DateTime(range.end.year, range.end.month, range.end.day, 23, 59, 59));
    final querySnapshot = await _completedCol.where('registeredAt', isGreaterThanOrEqualTo: start).where('registeredAt', isLessThanOrEqualTo: end).get();
    final customers = querySnapshot.docs.map((doc) => Customer.fromMap(doc.data())).toList();
    customers.sort((a, b) => b.registeredAt.compareTo(a.registeredAt));
    return customers;
  }

  Future<void> addCustomer(String name, String phone, int pax, int children, String operatorName) async {
    final customer = Customer(token: _nextToken, name: name, phone: phone, pax: pax, children: children, registeredAt: DateTime.now(), operator: operatorName, isCalled: false);
    await _firestore.collection('branches/$branchId/queue').doc(customer.token.toString()).set(customer.toMap());
    final newNextToken = _nextToken + 1;
    await _settingsDoc.set({'nextToken': newNextToken}, SetOptions(merge: true));
  }

  Future<void> markAsCalled(int token) async {
    await _firestore.collection('branches/$branchId/queue').doc(token.toString()).update({'isCalled': true});
  }

  // --- FIX for the Dismissible Bug ---
  // The old `callNext` method has been replaced by the following two methods.

  /// This is the new public method that the UI will call upon swiping.
  void seatCustomer(Customer customer, String waiterName) {
    // Step 1: Remove the customer from the local list immediately.
    _queue.removeWhere((c) => c.token == customer.token);

    // Step 2: Notify the UI right away to rebuild without the dismissed item.
    // This synchronous update prevents the red screen error.
    notifyListeners();

    // Step 3: Perform the database operations in the background.
    _moveCustomerToCompleted(customer, waiterName);
  }

  /// This is now a private helper method for the database logic.
  Future<void> _moveCustomerToCompleted(Customer customer, String waiterName) async {
    // Set the final "seated at" time and waiter name
    customer.calledAt = DateTime.now();
    customer.waiterName = waiterName;

    // Add to the 'completed' collection in Firestore
    await _completedCol.add(customer.toMap());

    // Delete from the 'queue' collection in Firestore
    await _firestore.collection('branches/$branchId/queue').doc(customer.token.toString()).delete();

    // Update the 'nowServing' token
    await _settingsDoc.set({'nowServing': customer.token}, SetOptions(merge: true));
  }

  /// Mark a table as available. Allows duplicates and updates the UI instantly.
  Future<void> addTable(int tableNumber) async {
    _availableTables.add(tableNumber);
    _availableTables.sort();
    notifyListeners();
    await _settingsDoc.set({'availableTables': _availableTables}, SetOptions(merge: true));
  }

  /// Remove a table from availability and update the UI instantly.
  Future<void> removeTable(int tableNumber) async {
    if (_availableTables.remove(tableNumber)) {
      notifyListeners();
      await _settingsDoc.set({'availableTables': _availableTables}, SetOptions(merge: true));
    }
  }
}