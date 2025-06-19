import 'dart:io';
import 'screens/admin/queue_reports_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';

// Models
import 'models/customer.dart';
import 'models/app_user.dart';
import 'models/hall.dart';
import 'models/slot.dart';
import 'models/banquet_booking.dart';
import 'models/menu.dart';
import 'models/menu_category.dart';
import 'models/menu_item.dart';

// Providers
import 'providers/token_provider.dart';
import 'providers/user_provider.dart';
import 'providers/banquet_provider.dart';

// Screens
import 'screens/login_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/admin/user_management_screen.dart';
import 'screens/admin/menu_management_screen.dart';
import 'screens/admin/reports_screen.dart';
import 'screens/admin/combined_reports_screen.dart';
import 'screens/podium_operator_screen.dart';
import 'screens/waiter_screen.dart';
import 'screens/customer_screen.dart';
import 'screens/banquet/banquet_calendar_screen.dart';
import 'screens/banquet/hall_slot_management_screen.dart';
import 'screens/banquet/banquet_bookings_report_screen.dart';
import 'screens/banquet/booking_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();

  Hive.registerAdapter(CustomerAdapter());
  Hive.registerAdapter(AppUserAdapter());
  Hive.registerAdapter(HallAdapter());
  Hive.registerAdapter(SlotAdapter());
  Hive.registerAdapter(BanquetBookingAdapter());
  Hive.registerAdapter(MenuAdapter());
  Hive.registerAdapter(MenuCategoryAdapter());
  Hive.registerAdapter(MenuItemAdapter());

  await Hive.openBox<Customer>('customerQueue');
  await Hive.openBox<int>('settings');
  await Hive.openBox<AppUser>('users');
  await Hive.openBox<Customer>('completedQueue');
  await Hive.openBox<Hall>('halls');
  await Hive.openBox<Slot>('slots');
  await Hive.openBox<BanquetBooking>('banquetBookings');
  await Hive.openBox<Menu>('menus');
  await Hive.openBox<MenuCategory>('menuCategories');
  await Hive.openBox<MenuItem>('menuItems');

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => TokenProvider()..loadData()),
        ChangeNotifierProvider(create: (_) => UserProvider()..loadInitialUsers()),
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
      title: 'Token Management App',
      theme: ThemeData(primarySwatch: Colors.blue),
      initialRoute: '/',
      routes: {
        '/': (_) => LoginScreen(),
        '/dashboard': (_) => DashboardScreen(),
        '/admin/users': (_) => UserManagementScreen(),
        '/admin/menus': (_) => MenuManagementScreen(),
        '/admin/combined_reports': (_) => CombinedReportsScreen(),
        '/admin/reports': (_) => ReportsScreen(),
        '/reports/queue': (_) => QueueReportsScreen(),
        '/podium': (_) => PodiumOperatorScreen(),
        '/waiter': (_) => WaiterScreen(),
        '/customer': (_) => CustomerScreen(),
        '/banquet': (_) => BanquetCalendarScreen(),
        '/banquet/setup': (_) => HallSlotManagementScreen(),
        '/banquet/bookings': (_) => BanquetBookingsReportScreen(),
      },
      onGenerateRoute: (settings) {
        if (settings.name == '/banquet/book') {
          final args = settings.arguments as Map<String, dynamic>;
          return MaterialPageRoute(
            builder: (_) => BookingPage(
              date: args['date'],
              hallName: args['hallName'],
              slotLabel: args['slotLabel'],
            ),
          );
        }
        return null;
      },
    );
  }
}