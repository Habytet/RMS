import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import '../models/app_user.dart';

class DashboardScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserProvider>().currentUser;

    if (user == null) {
      Future.microtask(() => Navigator.pushReplacementNamed(context, '/'));
      return Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Dashboard'),
        actions: [
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: () {
              context.read<UserProvider>().logout();
              Navigator.pushReplacementNamed(context, '/');
            },
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: GridView.count(
          crossAxisCount: 1,
          childAspectRatio: 2.5,
          children: [
            _moduleCard(context, 'Queue', Icons.people, () {
              _openQueueModule(context, user);
            }),
            _moduleCard(context, 'Banquet', Icons.apartment, () {
              _openBanquetModule(context, user);
            }),
            if (user.queueReportsEnabled || user.banquetReportsEnabled || user.isAdmin)
              _moduleCard(context, 'Reports', Icons.bar_chart, () {
                _openReportsModule(context, user);
              }),
            if (user.isAdmin) _moduleCard(context, 'Admin', Icons.admin_panel_settings, () {
              _openAdminModule(context, user);
            }),
          ],
        ),
      ),
    );
  }

  Widget _moduleCard(BuildContext context, String label, IconData icon, VoidCallback onTap) {
    return Card(
      elevation: 4,
      margin: const EdgeInsets.all(12),
      child: InkWell(
        onTap: onTap,
        child: Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 32),
              SizedBox(width: 16),
              Text(label, style: TextStyle(fontSize: 24)),
            ],
          ),
        ),
      ),
    );
  }

  void _openQueueModule(BuildContext context, AppUser user) {
    final items = <Map<String, String>>[];

    if (user.podiumEnabled) items.add({'title': 'Podium Operator', 'route': '/podium'});
    if (user.waiterEnabled) items.add({'title': 'Waiter', 'route': '/waiter'});
    if (user.customerEnabled) items.add({'title': 'Customer Display', 'route': '/customer'});

    _openSubMenu(context, 'Queue Module', items);
  }

  void _openBanquetModule(BuildContext context, AppUser user) {
    final items = <Map<String, String>>[];

    if (user.banquetBookingEnabled || user.isAdmin) {
      items.add({'title': 'Banquet Booking', 'route': '/banquet'});
    }
    if (user.isAdmin) {
      items.add({'title': 'Banquet Setup', 'route': '/banquet/setup'});
      items.add({'title': 'View Bookings', 'route': '/banquet/bookings'});
    }

    _openSubMenu(context, 'Banquet Module', items);
  }

  void _openReportsModule(BuildContext context, AppUser user) {
    final items = <Map<String, String>>[];

    if (user.queueReportsEnabled || user.isAdmin) {
      items.add({'title': 'Queue Reports', 'route': '/admin/queue_reports'});
    }
    if (user.banquetReportsEnabled || user.isAdmin) {
    }
    if (user.isAdmin) {
      items.add({'title': 'Legacy Reports', 'route': '/admin/reports'});
    }

    _openSubMenu(context, 'Reports', items);
  }

  void _openAdminModule(BuildContext context, AppUser user) {
    final items = <Map<String, String>>[];

    if (user.isAdmin) {
      items.add({'title': 'User Management', 'route': '/admin/users'});
      items.add({'title': 'Menu Management', 'route': '/admin/menus'});
    }

    _openSubMenu(context, 'Admin Module', items);
  }

  void _openSubMenu(BuildContext context, String title, List<Map<String, String>> items) {
    showModalBottomSheet(
      context: context,
      builder: (_) => ListView(
        shrinkWrap: true,
        children: [
          ListTile(title: Text(title, style: TextStyle(fontWeight: FontWeight.bold))),
          Divider(),
          ...items.map((i) => ListTile(
            title: Text(i['title']!),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, i['route']!);
            },
          )),
        ],
      ),
    );
  }
}