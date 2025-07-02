import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/customer.dart';
import '../models/table.dart';

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
  List<RestaurantTable> _availableTables = [];
  bool _isLoading = true;

  // --- Admin-specific state for branch selection ---
  String? _adminSelectedBranchId;
  DocumentReference<Map<String, dynamic>>? _adminSettingsDoc;
  StreamSubscription? _adminSettingsSubscription;

  // --- Getters ---
  List<Customer> get queue => _queue;
  List<RestaurantTable> get availableTables =>
      List.unmodifiable(_availableTables);
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

    // Add a timeout to prevent infinite loading
    Future.delayed(const Duration(seconds: 10), () {
      if (_isLoading) {
        print('Loading timeout reached, setting isLoading to false');
        _isLoading = false;
        notifyListeners();
      }
    });

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
          // Convert the data to RestaurantTable objects
          final tablesData = data['availableTables'] as List<dynamic>? ?? [];
          _availableTables = tablesData.map((tableData) {
            if (tableData is Map<String, dynamic>) {
              return RestaurantTable.fromMap(tableData);
            } else if (tableData is int) {
              // Handle legacy data (just table numbers)
              return RestaurantTable(
                  number: tableData, capacity: 4); // Default capacity
            }
            return RestaurantTable(number: 0, capacity: 4); // Fallback
          }).toList();
          notifyListeners();
        }
      });

      // Also listen to the selected branch's queue for real-time updates
      final queueQuery = branchRef.collection('queue').orderBy('token');
      _queueSubscription = queueQuery.snapshots().listen(
        (snapshot) {
          _queue = snapshot.docs.map((doc) {
            final customer = Customer.fromMap(doc.data());
            customer.branchName = branchId; // Set the branch name for filtering
            return customer;
          }).toList();
          _isLoading = false;
          notifyListeners();
        },
        onError: (error) {
          print('Error listening to admin branch queue: $error');
          _isLoading = false;
          notifyListeners();
        },
      );
    } else {
      _resetLocalStateForAdmin();
      // Reset to collection group query for 'all' view
      _listenToQueueCollectionGroup();
    }
    notifyListeners();
  }

  void _listenToQueue() {
    _queueSubscription = _queueQuery.snapshots().listen(
      (snapshot) {
        _queue =
            snapshot.docs.map((doc) => Customer.fromMap(doc.data())).toList();
        _isLoading = false;
        notifyListeners();
      },
      onError: (error) {
        print('Error listening to queue: $error');
        _isLoading = false;
        notifyListeners();
      },
    );
  }

  void _listenToQueueCollectionGroup() {
    _queueSubscription = _queueQuery.snapshots().listen(
      (snapshot) {
        print(
            'Collection group snapshot received with ${snapshot.docs.length} documents');
        _queue = snapshot.docs.map((doc) {
          final customer = Customer.fromMap(doc.data());

          // Extract branch ID from the document path
          // Path format: branches/{branchId}/queue/{token}
          final pathParts = doc.reference.path.split('/');
          String branchId = 'Unknown';

          if (pathParts.length >= 3 && pathParts[0] == 'branches') {
            branchId = pathParts[1];
          } else {
            // Fallback to the old method
            branchId = doc.reference.parent.parent?.id ?? 'Unknown';
          }

          customer.branchName = branchId;
          print(
              'Customer ${customer.name} from branch: $branchId (path: ${doc.reference.path})');
          return customer;
        }).toList();

        // Debug: Print all unique branch names
        final uniqueBranches = _queue.map((c) => c.branchName).toSet();
        print('Unique branches found: $uniqueBranches');
        print('Total customers: ${_queue.length}');

        _isLoading = false;
        notifyListeners();
      },
      onError: (error) {
        print('Error listening to queue collection group: $error');
        _isLoading = false;
        notifyListeners();
      },
    );
  }

  void _listenToSettings() {
    _settingsSubscription = _settingsDoc!.snapshots().listen((snap) {
      final data = snap.data();
      if (data != null) {
        _nowServing = data['nowServing'] as int?;
        _nextToken = data['nextToken'] as int? ?? 1;
        // Convert the data to RestaurantTable objects
        final tablesData = data['availableTables'] as List<dynamic>? ?? [];
        _availableTables = tablesData.map((tableData) {
          if (tableData is Map<String, dynamic>) {
            return RestaurantTable.fromMap(tableData);
          } else if (tableData is int) {
            // Handle legacy data (just table numbers)
            return RestaurantTable(
                number: tableData, capacity: 4); // Default capacity
          }
          return RestaurantTable(number: 0, capacity: 4); // Fallback
        }).toList();
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

  // Updated to accept both table number and capacity
  Future<void> addTable(int tableNumber, int capacity) async {
    final String effectiveBranchId = _adminSelectedBranchId ?? branchId;
    if (effectiveBranchId == 'all' || effectiveBranchId.isEmpty) {
      throw Exception("Cannot add table in 'All Branches' view.");
    }
    final branchDoc = _firestore.collection('branches').doc(effectiveBranchId);
    await _firestore.runTransaction((tx) async {
      final snap = await tx.get(branchDoc);
      // Convert existing data to RestaurantTable objects
      final tablesData =
          snap.data()?['availableTables'] as List<dynamic>? ?? [];
      final currentTables = tablesData.map((tableData) {
        if (tableData is Map<String, dynamic>) {
          return RestaurantTable.fromMap(tableData);
        } else if (tableData is int) {
          // Handle legacy data (just table numbers)
          return RestaurantTable(
              number: tableData, capacity: 4); // Default capacity
        }
        return RestaurantTable(number: 0, capacity: 4); // Fallback
      }).toList();

      currentTables
          .add(RestaurantTable(number: tableNumber, capacity: capacity));
      // Sort the list for consistent display.
      currentTables.sort((a, b) => a.number.compareTo(b.number));

      // Convert back to map format for storage
      final tablesForStorage =
          currentTables.map((table) => table.toMap()).toList();
      tx.update(branchDoc, {'availableTables': tablesForStorage});
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
    customer.seatedAt = DateTime.now(); // Set the actual seating time

    print('DEBUG: Moving customer to completed:');
    print('  token: ${customer.token}');
    print('  name: ${customer.name}');
    print('  registeredAt: ${customer.registeredAt}');
    print('  seatedAt: ${customer.seatedAt}');
    print('  branchId: $branchId');

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
      // Convert existing data to RestaurantTable objects
      final tablesData =
          snap.data()?['availableTables'] as List<dynamic>? ?? [];
      final currentTables = tablesData.map((tableData) {
        if (tableData is Map<String, dynamic>) {
          return RestaurantTable.fromMap(tableData);
        } else if (tableData is int) {
          // Handle legacy data (just table numbers)
          return RestaurantTable(
              number: tableData, capacity: 4); // Default capacity
        }
        return RestaurantTable(number: 0, capacity: 4); // Fallback
      }).toList();

      // Remove the first table with matching number
      final index =
          currentTables.indexWhere((table) => table.number == tableNumber);
      if (index != -1) {
        currentTables.removeAt(index);
      }

      // Convert back to map format for storage
      final tablesForStorage =
          currentTables.map((table) => table.toMap()).toList();
      tx.update(branchDoc, {'availableTables': tablesForStorage});
    });

    // The real-time listeners will automatically update the UI
  }

  Future<void> assignTableToCustomer(Customer customer, int tableNumber) async {
    final String effectiveBranchId = _adminSelectedBranchId ?? branchId;
    if (effectiveBranchId == 'all' || effectiveBranchId.isEmpty) {
      throw Exception("Cannot assign table in 'All Branches' view.");
    }

    final branchDoc = _firestore.collection('branches').doc(effectiveBranchId);

    await _firestore.runTransaction((tx) async {
      // First, read the branch document to get current available tables
      final snap = await tx.get(branchDoc);
      final tablesData =
          snap.data()?['availableTables'] as List<dynamic>? ?? [];
      final currentTables = tablesData.map((tableData) {
        if (tableData is Map<String, dynamic>) {
          return RestaurantTable.fromMap(tableData);
        } else if (tableData is int) {
          // Handle legacy data (just table numbers)
          return RestaurantTable(number: tableData, capacity: 4);
        }
        return RestaurantTable(number: 0, capacity: 4);
      }).toList();

      // Remove the assigned table
      currentTables.removeWhere((table) => table.number == tableNumber);

      // Convert back to map format for storage
      final tablesForStorage =
          currentTables.map((table) => table.toMap()).toList();

      // Now perform all writes after all reads
      tx.update(branchDoc.collection('queue').doc(customer.token.toString()),
          {'assignedTableNumber': tableNumber});
      tx.update(branchDoc, {'availableTables': tablesForStorage});
    });
  }

  // Method to get all customers from today (both in queue and completed)
  Future<List<Customer>> getTodaysCustomers(String? branchIdOverride) async {
    final String effectiveBranchId =
        branchIdOverride ?? _adminSelectedBranchId ?? branchId;
    if (effectiveBranchId == 'all' || effectiveBranchId.isEmpty) {
      throw Exception("Cannot get today's customers in 'All Branches' view.");
    }

    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    final branchRef = _firestore.collection('branches').doc(effectiveBranchId);

    // Get customers from queue collection
    final queueQuery = branchRef
        .collection('queue')
        .where('registeredAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('registeredAt', isLessThan: Timestamp.fromDate(endOfDay));

    // Get customers from completed collection
    final completedQuery = branchRef
        .collection('completed')
        .where('registeredAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('registeredAt', isLessThan: Timestamp.fromDate(endOfDay));

    final queueSnapshot = await queueQuery.get();
    final completedSnapshot = await completedQuery.get();

    final queueCustomers = queueSnapshot.docs.map((doc) {
      final customer = Customer.fromMap(doc.data());
      customer.branchName = effectiveBranchId;
      return customer;
    }).toList();

    final completedCustomers = completedSnapshot.docs.map((doc) {
      final customer = Customer.fromMap(doc.data());
      customer.branchName = effectiveBranchId;
      return customer;
    }).toList();

    // Combine and sort by registration time
    final allCustomers = [...queueCustomers, ...completedCustomers];
    allCustomers.sort((a, b) => a.registeredAt.compareTo(b.registeredAt));

    return allCustomers;
  }
}
