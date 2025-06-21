import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/customer.dart';

class TokenProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String branchId;

  late final Query<Map<String, dynamic>> _queueQuery;
  late final CollectionReference<Map<String, dynamic>>? _completedCol;
  late final DocumentReference<Map<String, dynamic>>? _settingsDoc;

  StreamSubscription? _queueSubscription;
  StreamSubscription? _settingsSubscription;

  // --- State Variables ---
  int _nextToken = 1;
  int? _nowServing;
  List<Customer> _queue = [];
  List<int> _availableTables = [];
  bool _isLoading = true;

  // --- Getters ---
  int get nextToken => _nextToken;
  int? get nowServing => _nowServing;
  List<Customer> get queue => _queue;
  List<int> get availableTables => List.unmodifiable(_availableTables);
  bool get isLoading => _isLoading;

  TokenProvider({required this.branchId}) {
    _init();
  }

  void _init() {
    _isLoading = true;
    notifyListeners();

    _queueSubscription?.cancel();
    _settingsSubscription?.cancel();

    if (branchId == 'all') {
      _queueQuery = _firestore.collectionGroup('queue').orderBy('token');
      _completedCol = null;
      _settingsDoc = null;
      _listenToQueueCollectionGroup();
      _resetLocalStateForAdmin();
    } else {
      final branchRef = _firestore.collection('branches').doc(branchId);
      _queueQuery = branchRef.collection('queue').orderBy('token');
      _completedCol = branchRef.collection('completed');
      _settingsDoc = branchRef;
      _listenToQueue();
      _listenToSettings();
    }
  }

  void _listenToQueue() {
    _queueSubscription = _queueQuery.snapshots().listen((snapshot) {
      _queue = snapshot.docs.map((doc) => Customer.fromMap(doc.data())).toList();
      _isLoading = false;
      notifyListeners();
    });
  }

  void _listenToQueueCollectionGroup() {
    _queueSubscription = _queueQuery.snapshots().listen((snapshot) {
      _queue = snapshot.docs.map((doc) {
        final customer = Customer.fromMap(doc.data());
        customer.branchName = doc.reference.parent.parent?.id ?? 'Unknown';
        return customer;
      }).toList();
      _isLoading = false;
      notifyListeners();
    });
  }

  void _listenToSettings() {
    _settingsSubscription = _settingsDoc!.snapshots().listen((snap) {
      final data = snap.data();
      if (data != null) {
        _nowServing = data['nowServing'] as int?;
        _nextToken = data['nextToken'] as int? ?? 1;
        _availableTables = List<int>.from(data['availableTables'] ?? []);
        notifyListeners();
      }
    });
  }

  void _resetLocalStateForAdmin() {
    _nextToken = 0;
    _nowServing = null;
    _availableTables = [];
  }

  Future<void> addCustomer(String name, String phone, int pax, int children, String operatorName) async {
    if (branchId == 'all' || _settingsDoc == null) {
      throw Exception("Cannot add customer in 'All Branches' view.");
    }
    await _firestore.runTransaction((transaction) async {
      final settingsSnap = await transaction.get(_settingsDoc!);
      final currentToken = settingsSnap.data()?['nextToken'] as int? ?? 1;
      final newCustomer = Customer(
        token: currentToken,
        name: name,
        phone: phone,
        pax: pax,
        children: children,
        registeredAt: DateTime.now(),
        operator: operatorName,
        isCalled: false,
      );
      final newCustomerRef = _settingsDoc!.collection('queue').doc(currentToken.toString());
      transaction.set(newCustomerRef, newCustomer.toMap());
      transaction.update(_settingsDoc!, {'nextToken': currentToken + 1});
    });
  }

  // --- THIS IS THE FIX ---
  // Reverted the logic back to using a List to allow duplicate table numbers.
  Future<void> addTable(int tableNumber) async {
    if (branchId == 'all' || _settingsDoc == null) {
      throw Exception("Cannot add table in 'All Branches' view.");
    }
    await _firestore.runTransaction((tx) async {
      final snap = await tx.get(_settingsDoc!);
      // Use a List instead of a Set to allow duplicates.
      final currentTables = List<int>.from(snap.data()?['availableTables'] ?? []);
      currentTables.add(tableNumber);
      // Sort the list for consistent display.
      currentTables.sort();
      tx.update(_settingsDoc!, {'availableTables': currentTables});
    });
  }

  @override
  void dispose() {
    _queueSubscription?.cancel();
    _settingsSubscription?.cancel();
    super.dispose();
  }

  Future<void> markAsCalled(int token) async {
    if (branchId == 'all') {
      throw Exception("Cannot mark as called in 'All Branches' view.");
    }
    await _firestore
        .collection('branches/$branchId/queue')
        .doc(token.toString())
        .update({'isCalled': true, 'calledAt': FieldValue.serverTimestamp()});
  }

  void seatCustomer(Customer customer, String waiterName) {
    if (branchId == 'all' || _completedCol == null) {
      throw Exception("Cannot seat customer in 'All Branches' view.");
    }
    _queue.removeWhere((c) => c.token == customer.token);
    notifyListeners();
    _moveCustomerToCompleted(customer, waiterName);
  }

  Future<void> _moveCustomerToCompleted(Customer customer, String waiterName) async {
    customer.waiterName = waiterName;
    await _completedCol!.add(customer.toMap());
    await _firestore
        .collection('branches/$branchId/queue')
        .doc(customer.token.toString())
        .delete();
    await _settingsDoc!.set({'nowServing': customer.token}, SetOptions(merge: true));
  }

  Future<void> removeTable(int tableNumber) async {
    if (branchId == 'all' || _settingsDoc == null) {
      throw Exception("Cannot remove table in 'All Branches' view.");
    }
    await _firestore.runTransaction((tx) async {
      final snap = await tx.get(_settingsDoc!);
      final currentTables = List<int>.from(snap.data()?['availableTables'] ?? []);
      // This correctly removes only the first instance of the number, which is what you want.
      currentTables.remove(tableNumber);
      tx.update(_settingsDoc!, {'availableTables': currentTables});
    });
  }
}