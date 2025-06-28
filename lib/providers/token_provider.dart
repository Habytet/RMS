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

  // --- Admin-specific state for branch selection ---
  String? _adminSelectedBranchId;
  DocumentReference<Map<String, dynamic>>? _adminSettingsDoc;
  StreamSubscription? _adminSettingsSubscription;

  // --- Getters ---
  List<Customer> get queue => _queue;
  List<int> get availableTables => List.unmodifiable(_availableTables);
  int get nextToken => _nextToken;
  int? get nowServing => _nowServing;
  bool get isLoading => _isLoading;
  String? get adminSelectedBranchId => _adminSelectedBranchId;

  TokenProvider({required this.branchId}) {
    _init();
  }

  void _init() {
    _isLoading = true;
    notifyListeners();

    _queueSubscription?.cancel();
    _settingsSubscription?.cancel();
    _adminSettingsSubscription?.cancel();

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

  // Method for admin to select a specific branch
  void selectBranchForAdmin(String branchId) {
    if (this.branchId != 'all') return; // Only for admin users

    _adminSelectedBranchId = branchId;
    _adminSettingsSubscription?.cancel();
    _queueSubscription?.cancel();

    if (branchId != 'all' && branchId.isNotEmpty) {
      // Set up listeners for the selected branch
      final branchRef = _firestore.collection('branches').doc(branchId);
      _adminSettingsDoc = branchRef;

      // Listen to the selected branch's settings (nextToken, availableTables, nowServing)
      _adminSettingsSubscription =
          _adminSettingsDoc!.snapshots().listen((snap) {
        final data = snap.data();
        if (data != null) {
          _nextToken = data['nextToken'] as int? ?? 1;
          _nowServing = data['nowServing'] as int?;
          _availableTables = List<int>.from(data['availableTables'] ?? []);
          notifyListeners();
        }
      });

      // Also listen to the selected branch's queue for real-time updates
      final queueQuery = branchRef.collection('queue').orderBy('token');
      _queueSubscription = queueQuery.snapshots().listen((snapshot) {
        _queue = snapshot.docs.map((doc) {
          final customer = Customer.fromMap(doc.data());
          customer.branchName = branchId; // Set the branch name for filtering
          return customer;
        }).toList();
        _isLoading = false;
        notifyListeners();
      });
    } else {
      _resetLocalStateForAdmin();
      // Reset to collection group query for 'all' view
      _listenToQueueCollectionGroup();
    }
    notifyListeners();
  }

  void _listenToQueue() {
    _queueSubscription = _queueQuery.snapshots().listen((snapshot) {
      _queue =
          snapshot.docs.map((doc) => Customer.fromMap(doc.data())).toList();
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

  Future<void> addCustomer(
      String name, String phone, int pax, int children, String operatorName,
      {String? branchIdOverride}) async {
    final String effectiveBranchId = branchIdOverride ?? branchId;
    if (effectiveBranchId == 'all' || effectiveBranchId.isEmpty) {
      throw Exception("Cannot add customer in 'All Branches' view.");
    }
    final branchDoc = _firestore.collection('branches').doc(effectiveBranchId);
    final settingsDoc = branchDoc;
    await _firestore.runTransaction((transaction) async {
      final settingsSnap = await transaction.get(settingsDoc);
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
      final newCustomerRef =
          branchDoc.collection('queue').doc(currentToken.toString());
      transaction.set(newCustomerRef, newCustomer.toMap());
      transaction.update(settingsDoc, {'nextToken': currentToken + 1});
    });

    // The real-time listeners will automatically update the UI
  }

  // --- THIS IS THE FIX ---
  // Reverted the logic back to using a List to allow duplicate table numbers.
  Future<void> addTable(int tableNumber) async {
    final String effectiveBranchId = _adminSelectedBranchId ?? branchId;
    if (effectiveBranchId == 'all' || effectiveBranchId.isEmpty) {
      throw Exception("Cannot add table in 'All Branches' view.");
    }
    final branchDoc = _firestore.collection('branches').doc(effectiveBranchId);
    await _firestore.runTransaction((tx) async {
      final snap = await tx.get(branchDoc);
      // Use a List instead of a Set to allow duplicates.
      final currentTables =
          List<int>.from(snap.data()?['availableTables'] ?? []);
      currentTables.add(tableNumber);
      // Sort the list for consistent display.
      currentTables.sort();
      tx.update(branchDoc, {'availableTables': currentTables});
    });

    // The real-time listeners will automatically update the UI
  }

  @override
  void dispose() {
    _queueSubscription?.cancel();
    _settingsSubscription?.cancel();
    _adminSettingsSubscription?.cancel();
    super.dispose();
  }

  Future<void> markAsCalled(int token) async {
    final String effectiveBranchId = _adminSelectedBranchId ?? branchId;
    if (effectiveBranchId == 'all' || effectiveBranchId.isEmpty) {
      throw Exception("Cannot mark as called in 'All Branches' view.");
    }
    await _firestore
        .collection('branches/$effectiveBranchId/queue')
        .doc(token.toString())
        .update({'isCalled': true, 'calledAt': FieldValue.serverTimestamp()});
  }

  void seatCustomer(Customer customer, String waiterName) {
    final String effectiveBranchId = _adminSelectedBranchId ?? branchId;
    if (effectiveBranchId == 'all' || effectiveBranchId.isEmpty) {
      throw Exception("Cannot seat customer in 'All Branches' view.");
    }
    _queue.removeWhere((c) => c.token == customer.token);
    notifyListeners();
    _moveCustomerToCompleted(customer, waiterName, effectiveBranchId);
  }

  Future<void> _moveCustomerToCompleted(
      Customer customer, String waiterName, String branchId) async {
    customer.waiterName = waiterName;
    final branchRef = _firestore.collection('branches').doc(branchId);
    final completedCol = branchRef.collection('completed');
    await completedCol.add(customer.toMap());
    await _firestore
        .collection('branches/$branchId/queue')
        .doc(customer.token.toString())
        .delete();
    await branchRef
        .set({'nowServing': customer.token}, SetOptions(merge: true));
  }

  Future<void> removeTable(int tableNumber) async {
    final String effectiveBranchId = _adminSelectedBranchId ?? branchId;
    if (effectiveBranchId == 'all' || effectiveBranchId.isEmpty) {
      throw Exception("Cannot remove table in 'All Branches' view.");
    }
    final branchDoc = _firestore.collection('branches').doc(effectiveBranchId);
    await _firestore.runTransaction((tx) async {
      final snap = await tx.get(branchDoc);
      final currentTables =
          List<int>.from(snap.data()?['availableTables'] ?? []);
      // This correctly removes only the first instance of the number, which is what you want.
      currentTables.remove(tableNumber);
      tx.update(branchDoc, {'availableTables': currentTables});
    });

    // The real-time listeners will automatically update the UI
  }
}
