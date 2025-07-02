import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:token_manager/screens/notification_screen/notification_bloc.dart';
import 'firebase_options.dart';

// --- PROVIDERS (No changes here) ---
import 'providers/user_provider.dart';
import 'providers/token_provider.dart';
import 'providers/banquet_provider.dart';
import 'providers/task_provider.dart';

// --- SCREENS (No changes here) ---
import 'screens/login_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/admin/user_management_screen.dart';
import 'screens/admin/menu_management_screen.dart';
import 'screens/admin/branch_management_screen.dart';
import 'screens/admin/queue_reports_screen.dart';
import 'screens/admin/banquet_reports_screen.dart';
import 'screens/queue/admin_display_screen.dart';
import 'screens/podium_operator_screen.dart';
import 'screens/waiter_table_screen.dart';
import 'screens/customer_screen.dart';
import 'screens/banquet/banquet_calendar_screen.dart';
import 'screens/banquet/hall_slot_management_screen.dart';
import 'screens/banquet/banquet_bookings_report_screen.dart';
import 'screens/banquet/chef_display_screen.dart';
import 'screens/banquet/edit_booking_page.dart';
import 'screens/banquet/select_menu_items_page.dart';
import 'screens/branch_manager/branch_manager_tasks_screen.dart';
import 'screens/branch_manager/branch_manager_task_detail_screen.dart';
import 'screens/manager_admin/staff_tasks_screen.dart';
import 'screens/manager_admin/create_new_task_screen.dart';
import 'screens/manager_admin/staff_assigned_task_detail_screen.dart';
import 'screens/manager_admin/staff_inprogress_task_detail_screen.dart';
import 'screens/manager_admin/staff_completed_task_detail_screen.dart';
import 'screens/notification_screen/notification_screen.dart';

// --- MODELS (No changes here) ---
import 'models/task.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => UserProvider()),
        ChangeNotifierProxyProvider<UserProvider, TokenProvider>(
          create: (_) => TokenProvider(branchId: 'all'),
          update: (_, userProvider, previousTokenProvider) => TokenProvider(
            branchId: userProvider.currentBranchId,
          ),
        ),
        ChangeNotifierProxyProvider<UserProvider, BanquetProvider>(
          create: (_) => BanquetProvider(branchId: 'all'),
          update: (_, userProvider, previousBanquetProvider) => BanquetProvider(
            branchId: userProvider.currentBranchId,
          ),
        ),
        ChangeNotifierProxyProvider<UserProvider, TaskProvider>(
          create: (_) => TaskProvider(branchId: 'all'),
          update: (_, userProvider, previousTaskProvider) => TaskProvider(
            branchId: userProvider.currentBranchId,
          ),
        ),
        BlocProvider(create: (_) => NotificationBloc()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Token & Banquet Manager',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const AuthWrapper(),
      routes: {
        '/login': (_) => const LoginScreen(),
        '/dashboard': (_) => const DashboardScreen(),
        '/admin/users': (_) => const UserManagementScreen(),
        '/admin/menus': (_) => MenuManagementScreen(),
        '/admin/branches': (_) => const BranchManagementScreen(),
        '/admin/queue_reports': (_) => const QueueReportsScreen(),
        '/admin/banquet_reports': (_) => const BanquetReportsScreen(),
        '/queue/admin_display': (_) => const AdminDisplayScreen(),
        '/podium': (_) => PodiumOperatorScreen(),
        '/waiter': (_) => WaiterTableScreen(),
        '/customer': (_) => CustomerScreen(),
        '/banquet': (_) => const BanquetCalendarScreen(),
        '/banquet/setup': (_) => HallSlotManagementScreen(),
        '/banquet/bookings': (_) => BanquetBookingsReportScreen(),
        '/banquet/chef_display': (_) => ChefDisplayScreen(),
        '/tasks/branch_manager': (_) => const BranchManagerTasksScreen(),
        '/tasks/manager_admin/staff_tasks': (_) => const StaffTasksScreen(),
        '/tasks/manager_admin/create_task': (_) => const CreateNewTaskScreen(),
        '/notifications': (_) =>
            NotificationScreen(bloc: BlocProvider.of<NotificationBloc>(_)),
      },
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case '/banquet/edit':
            final args = settings.arguments as Map<String, dynamic>;
            return MaterialPageRoute(
              builder: (_) => EditBookingPage(
                booking: args['booking'],
                docId: args['docId'],
                branchId: args['branchId'],
              ),
            );
          case '/banquet/select_items':
            final args = settings.arguments as Map<String, dynamic>;
            return MaterialPageRoute(
              builder: (_) => SelectMenuItemsPage(
                menu: args['menu'],
                initialSelections: args['initialSelections'],
                branchId: args['branchId'],
              ),
            );
          case '/tasks/branch_manager/detail':
            final args = settings.arguments as Map<String, dynamic>;
            return MaterialPageRoute(
              builder: (_) =>
                  BranchManagerTaskDetailScreen(task: args['task'] as Task),
            );
          case '/tasks/manager_admin/assigned_task_detail':
            final args = settings.arguments as Map<String, dynamic>;
            return MaterialPageRoute(
              builder: (_) =>
                  StaffAssignedTaskDetailScreen(task: args['task'] as Task),
            );
          case '/tasks/manager_admin/inprogress_task_detail':
            final args = settings.arguments as Map<String, dynamic>;
            return MaterialPageRoute(
              builder: (_) =>
                  StaffInProgressTaskDetailScreen(task: args['task'] as Task),
            );
          case '/tasks/manager_admin/completed_task_detail':
            final args = settings.arguments as Map<String, dynamic>;
            return MaterialPageRoute(
              builder: (_) =>
                  StaffCompletedTaskDetailScreen(task: args['task'] as Task),
            );
          default:
            return null;
        }
      },
    );
  }
}

// --- THIS IS THE ONLY WIDGET THAT HAS BEEN MODIFIED ---

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final authStatus = context.watch<UserProvider>().authStatus;

    return AnimatedSwitcher(
      // A slightly faster duration often feels more responsive
      duration: const Duration(milliseconds: 500),

      // --- REVISED, PERFORMANCE-OPTIMIZED TRANSITION ---
      transitionBuilder: (Widget child, Animation<double> animation) {
        // Use a highly optimized curve for screen transitions
        final curvedAnimation = CurvedAnimation(
          parent: animation,
          curve: Curves.fastOutSlowIn,
        );

        // We only apply the slide to the incoming Dashboard screen
        if (child.key == const ValueKey('DashboardScreen')) {
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(1.0, 0.0), // Start from the right
              end: Offset.zero,
            ).animate(curvedAnimation),
            child: child,
          );
        }

        // The LoginScreen will use the default fade transition, which is perfect.
        return FadeTransition(
          opacity: curvedAnimation,
          child: child,
        );
      },
      child: _buildChild(authStatus),
    );
  }

  // This helper method contains your original switch statement, unchanged.
  Widget _buildChild(AuthStatus status) {
    switch (status) {
      case AuthStatus.authenticated:
        return const DashboardScreen(key: ValueKey('DashboardScreen'));
      case AuthStatus.unauthenticated:
        return const LoginScreen(key: ValueKey('LoginScreen'));
      case AuthStatus.unknown:
        return const Scaffold(
          key: ValueKey('Loading'),
          body: Center(child: CircularProgressIndicator()),
        );
    }
  }
}
