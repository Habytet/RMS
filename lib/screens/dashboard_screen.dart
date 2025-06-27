import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import '../models/app_user.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authStatus = context.watch<UserProvider>().authStatus;
    final user = context.read<UserProvider>().currentUser;

    if (authStatus == AuthStatus.unauthenticated) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (authStatus == AuthStatus.unknown || user == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => context.read<UserProvider>().logout(),
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: GridView.count(
          crossAxisCount: 1,
          childAspectRatio: 2.5,
          children: [
            if (user.podiumEnabled ||
                user.waiterEnabled ||
                user.customerEnabled ||
                user.adminDisplayEnabled ||
                user.isAdmin)
              _moduleCard(context, 'Queue', Icons.people, () {
                _openQueueModule(context, user);
              }),
            if (user.banquetBookingEnabled ||
                user.banquetSetupEnabled ||
                user.banquetReportsEnabled ||
                user.isAdmin)
              _moduleCard(context, 'Banquet', Icons.apartment, () {
                _openBanquetModule(context, user);
              }),
            if (user.queueReportsEnabled ||
                user.banquetReportsEnabled ||
                user.isAdmin)
              _moduleCard(context, 'Reports', Icons.bar_chart, () {
                _openReportsModule(context, user);
              }),
            if (user.userManagementEnabled ||
                user.menuManagementEnabled ||
                user.branchManagementEnabled ||
                user.isAdmin)
              _moduleCard(context, 'Admin', Icons.admin_panel_settings, () {
                _openAdminModule(context, user);
              }),
          ],
        ),
      ),
    );
  }

  Widget _moduleCard(
      BuildContext context, String label, IconData icon, VoidCallback onTap) {
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
              const SizedBox(width: 16),
              Text(label, style: const TextStyle(fontSize: 24)),
            ],
          ),
        ),
      ),
    );
  }

  void _openQueueModule(BuildContext context, AppUser user) {
    final items = <Map<String, String>>[];
    if (user.adminDisplayEnabled) {
      items.add({'title': 'Admin Display', 'route': '/queue/admin_display'});
    }
    if (user.podiumEnabled)
      items.add({'title': 'Podium Operator', 'route': '/podium'});
    if (user.waiterEnabled) items.add({'title': 'Waiter', 'route': '/waiter'});
    if (user.customerEnabled)
      items.add({'title': 'Customer Display', 'route': '/customer'});
    _openSubMenu(context, 'Queue Module', items);
  }

  void _openBanquetModule(BuildContext context, AppUser user) {
    final items = <Map<String, String>>[];
    if (user.banquetBookingEnabled || user.isAdmin)
      items.add({'title': 'Banquet Booking', 'route': '/banquet'});
    if (user.banquetSetupEnabled || user.isAdmin)
      items.add({'title': 'Banquet Setup', 'route': '/banquet/setup'});
    if (user.banquetReportsEnabled || user.isAdmin)
      items.add({'title': 'View Bookings', 'route': '/banquet/bookings'});
    _openSubMenu(context, 'Banquet Module', items);
  }

  void _openReportsModule(BuildContext context, AppUser user) {
    final items = <Map<String, String>>[];
    if (user.queueReportsEnabled || user.isAdmin)
      items.add({'title': 'Queue Reports', 'route': '/admin/queue_reports'});
    _openSubMenu(context, 'Reports', items);
  }

  void _openAdminModule(BuildContext context, AppUser user) {
    final items = <Map<String, String>>[];
    if (user.userManagementEnabled || user.isAdmin)
      items.add({'title': 'User Management', 'route': '/admin/users'});
    if (user.menuManagementEnabled || user.isAdmin)
      items.add({'title': 'Menu Management', 'route': '/admin/menus'});
    if (user.branchManagementEnabled || user.isAdmin)
      items.add({'title': 'Branch Management', 'route': '/admin/branches'});
    _openSubMenu(context, 'Admin Module', items);
  }

  void _openSubMenu(
      BuildContext context, String title, List<Map<String, String>> items) {
    showModalBottomSheet(
      context: context,
      builder: (_) => ListView(
        shrinkWrap: true,
        children: [
          ListTile(
              title: Text(title,
                  style: const TextStyle(fontWeight: FontWeight.bold))),
          const Divider(),
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
