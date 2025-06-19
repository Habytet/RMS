import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import '../../models/app_user.dart';

class UserManagementScreen extends StatefulWidget {
  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _box = Hive.box<AppUser>('users');

  bool _podium = false;
  bool _waiter = false;
  bool _customer = false;
  bool _banquetBooking = false;
  bool _banquetReports = false;
  bool _queueReports = false;

  void _createUser() {
    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();

    if (username.isEmpty || password.isEmpty) return;

    final user = AppUser(
      username: username,
      password: password,
      podiumEnabled: _podium,
      waiterEnabled: _waiter,
      customerEnabled: _customer,
      banquetBookingEnabled: _banquetBooking,
      banquetReportsEnabled: _banquetReports,
      queueReportsEnabled: _queueReports,
    );

    _box.put(username, user);
    _usernameController.clear();
    _passwordController.clear();
    _resetToggles();
    setState(() {});
  }

  void _resetToggles() {
    _podium = false;
    _waiter = false;
    _customer = false;
    _banquetBooking = false;
    _banquetReports = false;
    _queueReports = false;
  }

  @override
  Widget build(BuildContext context) {
    final users = _box.values.toList();

    return Scaffold(
      appBar: AppBar(title: Text('User Management')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            TextField(controller: _usernameController, decoration: InputDecoration(labelText: 'Username')),
            TextField(controller: _passwordController, decoration: InputDecoration(labelText: 'Password')),
            SizedBox(height: 20),
            _sectionTitle('Queue Roles'),
            _switchTile('Podium Operator', _podium, (v) => setState(() => _podium = v)),
            _switchTile('Waiter', _waiter, (v) => setState(() => _waiter = v)),
            _switchTile('Customer Display', _customer, (v) => setState(() => _customer = v)),

            SizedBox(height: 12),
            _sectionTitle('Banquet Roles'),
            _switchTile('Banquet Booking', _banquetBooking, (v) => setState(() => _banquetBooking = v)),
            _switchTile('Banquet Reports', _banquetReports, (v) => setState(() => _banquetReports = v)),

            SizedBox(height: 12),
            _sectionTitle('Reporting'),
            _switchTile('Queue Reports', _queueReports, (v) => setState(() => _queueReports = v)),

            SizedBox(height: 20),
            ElevatedButton(onPressed: _createUser, child: Text('Create User')),
            Divider(height: 32),
            Text('Existing Users:', style: TextStyle(fontWeight: FontWeight.bold)),
            ...users.map((user) => ListTile(
              title: Text(user.username),
              subtitle: Text(_getRoles(user).join(', ')),
            )),
          ],
        ),
      ),
    );
  }

  Widget _switchTile(String label, bool value, ValueChanged<bool> onChanged) {
    return SwitchListTile(
      title: Text(label),
      value: value,
      onChanged: onChanged,
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 4),
      child: Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
    );
  }

  List<String> _getRoles(AppUser user) {
    final roles = <String>[];
    if (user.podiumEnabled) roles.add('Podium');
    if (user.waiterEnabled) roles.add('Waiter');
    if (user.customerEnabled) roles.add('Customer');
    if (user.banquetBookingEnabled) roles.add('Banquet');
    if (user.banquetReportsEnabled) roles.add('BanquetReports');
    if (user.queueReportsEnabled) roles.add('QueueReports');
    return roles;
  }
}