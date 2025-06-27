import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

import 'providers/user_provider.dart';
import 'providers/token_provider.dart';
import 'providers/banquet_provider.dart';

import 'screens/login_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/admin/user_management_screen.dart';
import 'screens/admin/menu_management_screen.dart';
import 'screens/admin/branch_management_screen.dart';
import 'screens/admin/queue_reports_screen.dart';
import 'screens/queue/admin_display_screen.dart';
import 'screens/podium_operator_screen.dart';
import 'screens/waiter_table_screen.dart';
import 'screens/customer_screen.dart';
import 'screens/banquet/banquet_calendar_screen.dart';
import 'screens/banquet/hall_slot_management_screen.dart';
import 'screens/banquet/banquet_bookings_report_screen.dart';
import 'screens/banquet/edit_booking_page.dart';
import 'screens/banquet/select_menu_items_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // In lib/main.dart

// ... (keep your existing imports)

  runApp(
    MultiProvider(
      providers: [
        // UserProvider is the source of truth for auth and user profile
        ChangeNotifierProvider(create: (_) => UserProvider()),

        // These ProxyProviders depend on UserProvider.
        // They will automatically update when the logged-in user or branch changes.
        ChangeNotifierProxyProvider<UserProvider, TokenProvider>(
          create: (_) => TokenProvider(branchId: 'all'), // Initial provider
          update: (_, userProvider, previousTokenProvider) => TokenProvider(
            branchId: userProvider.currentBranchId,
          ),
        ),

        ChangeNotifierProxyProvider<UserProvider, BanquetProvider>(
          create: (_) => BanquetProvider(branchId: 'all'), // Initial provider
          update: (_, userProvider, previousBanquetProvider) => BanquetProvider(
            branchId: userProvider.currentBranchId,
          ),
        ),
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
        '/dashboard': (_) => DashboardScreen(),
        '/admin/users': (_) => const UserManagementScreen(),
        '/admin/menus': (_) => MenuManagementScreen(),
        '/admin/branches': (_) => const BranchManagementScreen(),
        '/admin/queue_reports': (_) => const QueueReportsScreen(),
        '/queue/admin_display': (_) => const AdminDisplayScreen(),
        '/podium': (_) => PodiumOperatorScreen(),
        '/waiter': (_) => WaiterTableScreen(),
        '/customer': (_) => CustomerScreen(),
        '/banquet': (_) => const BanquetCalendarScreen(),
        '/banquet/setup': (_) => HallSlotManagementScreen(),
        '/banquet/bookings': (_) => BanquetBookingsReportScreen(),
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
                hallName: args['hallName'],
              ),
            );
          default:
            return null;
        }
      },
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final authStatus = context.watch<UserProvider>().authStatus;
    switch (authStatus) {
      case AuthStatus.authenticated:
        return DashboardScreen();
      case AuthStatus.unauthenticated:
        return const LoginScreen();
      case AuthStatus.unknown:
        return const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        );
    }
  }
}
