import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';
import 'package:token_manager/resources/app_navigator.dart';
import 'package:token_manager/screens/banquet/banquet_bookings_report_screen.dart';
import 'package:token_manager/screens/notification_screen/notification_bloc.dart';
import 'package:token_manager/screens/notification_screen/notification_event.dart';
import 'package:token_manager/screens/notification_screen/notification_screen.dart';
import '../providers/user_provider.dart';
import '../models/app_user.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with SingleTickerProviderStateMixin {

  final NotificationBloc _bloc = NotificationBloc();
  late final AnimationController _bgAnimationController;

  @override
  void initState() {
    super.initState();
    _bgAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 15),
    )
      ..repeat(reverse: true);
    super.initState();
    FirebaseMessaging.instance.getToken().then((token) {
      print("FCM Token: $token");
      if (token != null) {
        saveToken(token: token);
        _bloc.add(SetFcmTokenEvent(fcmToken: token));
      }
    });

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('Received message: ${message.notification?.title}');
      final title = message.notification?.title ?? 'No Title';
      final body = message.notification?.body ?? 'No Body';

      // Show a snackbar
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$title: $body'),
          duration: Duration(seconds: 5),
        ),
      );
    });
  }

  Future<void> saveToken({required String token}) async {
    try {
      await context.read<UserProvider>().saveFcm(token: token);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Token saved successfully'),
            backgroundColor: Colors.green));
        //Navigator.pop(context);
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Error saving token: $e'),
            backgroundColor: Colors.red));
    }
  }

  @override
  void dispose() {
    _bgAnimationController.dispose();
    super.dispose();
  }

  // MODIFIED: Background gradient colors are now ~20% darker.
  Widget _buildAnimatedBackground() {
    return AnimatedBuilder(
      animation: _bgAnimationController,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: const [
                Color(0xFFB83065), // Original: #E73C7E -> Darker Pink/Magenta
                Color(0xFFBE5F41), // Original: #EE7752 -> Darker Orange
              ],
              stops: const [0.0, 1.0],
              transform: GradientRotation(
                  _bgAnimationController.value * 3.1415 * 2),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = context
        .watch<UserProvider>()
        .currentUser;

    if (user == null) {
      return Scaffold(
        body: Stack(
          children: [
            _buildAnimatedBackground(),
            const Center(child: CircularProgressIndicator(color: Colors.white)),
          ],
        ),
      );
    }

    return Stack(
      children: [
        _buildAnimatedBackground(),
        Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            title: Text(
              'Dashboard',
              style: GoogleFonts.inter(fontWeight: FontWeight.bold),
            ),
            backgroundColor: Colors.white.withOpacity(0.1),
            foregroundColor: Colors.white,
            elevation: 0,
            actions: [
              IconButton(
                icon: const Icon(Icons.logout),
                tooltip: 'Logout',
                onPressed: () => context.read<UserProvider>().logout(),
              )
            ],
          ),
          body: Padding(
            padding: const EdgeInsets.all(16.0),
            child: GridView.count(
              crossAxisCount: 3,
              childAspectRatio: 0.9,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              children: [
                if (user.podiumEnabled ||
                    user.waiterEnabled ||
                    user.customerEnabled ||
                    user.adminDisplayEnabled ||
                    user.isAdmin)
                  _moduleCard(context, 'Queue', Icons.people_alt_outlined, () {
                    _openQueueModule(context, user);
                  }),
                if (user.banquetBookingEnabled ||
                    user.banquetSetupEnabled ||
                    user.banquetReportsEnabled ||
                    user.isAdmin)
                  _moduleCard(
                      context, 'Banquet', Icons.celebration_outlined, () {
                    _openBanquetModule(context, user);
                  }),
                if (user.canViewOwnTasks || user.canViewStaffTasks ||
                    user.isAdmin)
                  _moduleCard(context, 'Tasks', Icons.task_alt_outlined, () {
                    _openTasksModule(context, user);
                  }),
                if (user.queueReportsEnabled ||
                    user.banquetReportsEnabled ||
                    user.isAdmin)
                  _moduleCard(context, 'Reports', Icons.bar_chart_outlined, () {
                    _openReportsModule(context, user);
                  }),
                if (user.userManagementEnabled ||
                    user.menuManagementEnabled ||
                    user.branchManagementEnabled ||
                    user.isAdmin)
                  _moduleCard(context, 'Admin',
                      Icons.admin_panel_settings_outlined, () {
                        _openAdminModule(context, user);
                      }),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _moduleCard(BuildContext context, String label, IconData icon,
      VoidCallback onTap) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.2)),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(icon, size: 40, color: Colors.white),
                const SizedBox(height: 12),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openSubMenu(BuildContext context, String title,
      List<Map<String, String>> items) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          ClipRRect(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
              child: Container(
                decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                    border: Border(
                        top: BorderSide(color: Colors.white.withOpacity(0.2)))
                ),
                child: SafeArea(
                  child: ListView(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Text(
                          title,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const Divider(
                          color: Colors.white24, indent: 16, endIndent: 16),
                      ...items.map((i) =>
                          ListTile(
                            leading: const Icon(
                                Icons.arrow_forward_ios, size: 14,
                                color: Colors.white70),
                            title: Text(
                              i['title']!,
                              style: GoogleFonts.inter(
                                  color: Colors.white, fontSize: 16),
                            ),
                            onTap: () {
                              Navigator.pop(context);
                              if (i['title'] == 'View Bookings') {
                                AppNavigator.toPush(
                                    context: context,
                                    widget: BanquetBookingsReportScreen(
                                      notificationBloc: _bloc,
                                    ));
                              } else {
                                Navigator.pushNamed(context, i['route']!);
                              }
                            },
                          )),
                    ],
                  ),
                ),
              ),
            ),
          ),
    );
  }

  // --- LOGIC METHODS (UNCHANGED) ---

  void _openQueueModule(BuildContext context, AppUser user) {
    final items = <Map<String, String>>[];
    if (user.adminDisplayEnabled) {
      items.add({'title': 'Admin Display', 'route': '/queue/admin_display'});
    }
    if (user.podiumEnabled) {
      items.add({'title': 'Podium Operator', 'route': '/podium'});
    }
    if (user.waiterEnabled) items.add({'title': 'Waiter', 'route': '/waiter'});
    if (user.customerEnabled) {
      items.add({'title': 'Customer Display', 'route': '/customer'});
    }
    _openSubMenu(context, 'Queue Module', items);
  }

  void _openBanquetModule(BuildContext context, AppUser user) {
    final items = <Map<String, String>>[];
    if (user.banquetBookingEnabled || user.isAdmin) {
      items.add({'title': 'Banquet Booking', 'route': '/banquet'});
    }
    if (user.banquetSetupEnabled || user.isAdmin) {
      items.add({'title': 'Banquet Setup', 'route': '/banquet/setup'});
    }
    if (user.banquetReportsEnabled || user.isAdmin) {
      items.add({'title': 'View Bookings', 'route': '/banquet/bookings'});
    }
    _openSubMenu(context, 'Banquet Module', items);
  }

  void _openTasksModule(BuildContext context, AppUser user) {
    final items = <Map<String, String>>[];
    if (user.canViewOwnTasks || user.isAdmin) {
      items.add({'title': 'My Tasks', 'route': '/tasks/branch_manager'});
    }
    if (user.canViewStaffTasks || user.isAdmin) {
      items.add({
        'title': 'Staff Task Management',
        'route': '/tasks/manager_admin/staff_tasks'
      });
    }
    _openSubMenu(context, 'Task Management', items);
  }

  void _openReportsModule(BuildContext context, AppUser user) {
    final items = <Map<String, String>>[];
    if (user.queueReportsEnabled || user.isAdmin) {
      items.add({'title': 'Queue Reports', 'route': '/admin/queue_reports'});
    }
    _openSubMenu(context, 'Reports', items);
  }

  void _openAdminModule(BuildContext context, AppUser user) {
    final items = <Map<String, String>>[];
    if (user.userManagementEnabled || user.isAdmin) {
      items.add({'title': 'User Management', 'route': '/admin/users'});
    }
    if (user.menuManagementEnabled || user.isAdmin) {
      items.add({'title': 'Menu Management', 'route': '/admin/menus'});
    }
    if (user.branchManagementEnabled || user.isAdmin) {
      items.add({'title': 'Branch Management', 'route': '/admin/branches'});
    }
    _openSubMenu(context, 'Admin Module', items);
  }
}

//   void _openSubMenu(
//       BuildContext context, String title, List<Map<String, String>> items) {
//     showModalBottomSheet(
//       context: context,
//       builder: (_) => ListView(
//         shrinkWrap: true,
//         children: [
//           ListTile(
//               title: Text(title,
//                   style: const TextStyle(fontWeight: FontWeight.bold))),
//           const Divider(),
//           ...items.map((i) => ListTile(
//                 title: Text(i['title']!),
//                 onTap: () {
//                   Navigator.pop(context);
//                   if (i['title'] == 'View Bookings') {
//                     AppNavigator.toPush(
//                         context: context,
//                         widget: BanquetBookingsReportScreen(
//                           notificationBloc: _bloc,
//                         ));
//                   } else {
//                     Navigator.pushNamed(context, i['route']!);
//                   }
//                 },
//               )),
//         ],
//       ),
//     );
//   }
// }
