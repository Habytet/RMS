import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

// Models (Hive adapters still registered for offline caching)
import 'models/customer.dart';
import 'models/app_user.dart';
import 'models/hall.dart';
import 'models/slot.dart';
import 'models/banquet_booking.dart';
import 'models/menu.dart';
import 'models/menu_category.dart';
import 'models/menu_item.dart';

// Providers
import 'providers/user_provider.dart';
import 'providers/token_provider.dart';
import 'providers/banquet_provider.dart';

// Screens
import 'screens/login_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/admin/user_management_screen.dart';
import 'screens/admin/menu_management_screen.dart';
import 'screens/admin/reports_screen.dart';
import 'screens/admin/queue_reports_screen.dart';
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

  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Launch the app with providers
  runApp(
    MultiProvider(
      providers: [
        // UserProvider manages authentication and branch context
        ChangeNotifierProvider(
          create: (_) => UserProvider(),
        ),

        // TokenProvider scoped to the current branch from UserProvider
        ChangeNotifierProxyProvider<UserProvider, TokenProvider>(
          create: (_) => TokenProvider(branchId: 'all'),
          update: (_, userProv, __) =>
              TokenProvider(branchId: userProv.currentBranchId),
        ),

        // BanquetProvider uses Firestore directly
        ChangeNotifierProvider(create: (_) => BanquetProvider()),
      ],
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Token & Banquet Manager',
      theme: ThemeData(primarySwatch: Colors.blue),
      initialRoute: '/',
      routes: {
        '/': (_) => LoginScreen(),
        '/dashboard': (_) => DashboardScreen(),
        '/admin/users': (_) => UserManagementScreen(),
        '/admin/menus': (_) => MenuManagementScreen(),
        '/admin/reports': (_) => ReportsScreen(),
        '/admin/queue_reports': (_) => QueueReportsScreen(),
        '/podium': (_) => PodiumOperatorScreen(),
        '/waiter': (_) => WaiterTableScreen(),
        '/customer': (_) => CustomerScreen(),
        '/banquet': (_) => BanquetCalendarScreen(),
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
              ),
            );
          case '/banquet/select_items':
            final args = settings.arguments as Map<String, dynamic>;
            return MaterialPageRoute(
              builder: (_) => SelectMenuItemsPage(
                menu: args['menu'],
                initialSelections: args['initialSelections'],
              ),
            );
          default:
            return null;
        }
      },
    );
  }
}