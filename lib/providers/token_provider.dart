import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

import '../models/customer.dart';

class TokenProvider extends ChangeNotifier {
  final Box<Customer> _queueBox = Hive.box<Customer>('customerQueue');
  final Box<Customer> _completedBox = Hive.box<Customer>('completedQueue');
  final Box<int> _settingsBox = Hive.box<int>('settings');

  int _nextToken = 1;
  int? _nowServing;

  final List<int> _availableTables = [];

  int get nextToken => _nextToken;
  int? get nowServing => _nowServing;
  List<Customer> get queue => _queueBox.values.toList();
  List<Customer> get allHistory => _completedBox.values.toList();
  List<int> get availableTables => List.unmodifiable(_availableTables);

  Future<void> loadData() async {
    _nowServing = _settingsBox.get('nowServing');
    _nextToken = _settingsBox.get('nextToken') ?? 1;
    print('[DEBUG] loadData: nowServing=$_nowServing, nextToken=$_nextToken');
    notifyListeners();
  }

  void addCustomer(String name, String phone, int pax, int children) {
    final customer = Customer(
      token: _nextToken,
      name: name,
      phone: phone,
      pax: pax,
      children: children,
      registeredAt: DateTime.now(),
      operator: 'Operator1', // TODO: Dynamically fetch from UserProvider
    );

    _queueBox.put(customer.token, customer);
    print('[DEBUG] addCustomer: token=${customer.token}, name=${customer.name}, time=${customer.registeredAt}');

    _nextToken++;
    _settingsBox.put('nextToken', _nextToken);
    notifyListeners();
  }

  void callNext(int token) {
    final customer = _queueBox.get(token);
    print('[DEBUG] callNext invoked for token=$token, found=${customer != null}');

    if (customer != null) {
      customer.calledAt = DateTime.now();
      customer.save();
      print('[DEBUG] callNext: set calledAt=${customer.calledAt} for token=${customer.token}');

      _completedBox.add(customer);
      print('[DEBUG] Added to completedQueue: token=${customer.token}, name=${customer.name}, calledAt=${customer.calledAt}');
      print('[DEBUG] Completed queue size: ${_completedBox.length}');

      _nowServing = token;
      _settingsBox.put('nowServing', token);
      _queueBox.delete(token);
      notifyListeners();
    }
  }

  void addTable(int tableNumber) {
    if (!_availableTables.contains(tableNumber)) {
      _availableTables.add(tableNumber);
      notifyListeners();
    }
  }

  void removeTable(int tableNumber) {
    if (_availableTables.remove(tableNumber)) {
      notifyListeners();
    }
  }
}