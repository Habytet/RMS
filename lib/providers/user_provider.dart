import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import '../models/app_user.dart';

class UserProvider extends ChangeNotifier {
  final Box<AppUser> _userBox = Hive.box<AppUser>('users');

  AppUser? _currentUser;
  AppUser? get currentUser => _currentUser;

  Future<void> loadInitialUsers() async {
    if (_userBox.isEmpty) {
      final admin = AppUser(
        username: 'admin',
        password: 'admin123',
        podiumEnabled: true,
        waiterEnabled: true,
        customerEnabled: true,
      );
      await _userBox.put(admin.username, admin);
    }
  }

  Future<bool> login(String username, String password) async {
    final user = _userBox.get(username);
    if (user != null && user.password == password) {
      _currentUser = user;
      notifyListeners();
      return true;
    }
    return false;
  }

  void logout() {
    _currentUser = null;
    notifyListeners();
  }

  Future<void> addUser(AppUser user) async {
    await _userBox.put(user.username, user);
    notifyListeners();
  }

  Future<void> updateUser(AppUser user) async {
    await user.save();
    notifyListeners();
  }

  Future<void> deleteUser(String username) async {
    await _userBox.delete(username);
    notifyListeners();
  }

  List<AppUser> get allUsers => _userBox.values.toList();
}