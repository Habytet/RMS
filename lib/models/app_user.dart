import 'package:hive/hive.dart';

part 'app_user.g.dart';

@HiveType(typeId: 1)
class AppUser extends HiveObject {
  @HiveField(0)
  String username;

  @HiveField(1)
  String password;

  @HiveField(2)
  bool podiumEnabled;

  @HiveField(3)
  bool waiterEnabled;

  @HiveField(4)
  bool customerEnabled;

  // ✅ New Feature Toggles
  @HiveField(5)
  bool banquetBookingEnabled;

  @HiveField(6)
  bool banquetReportsEnabled;

  @HiveField(7)
  bool queueReportsEnabled;

  AppUser({
    required this.username,
    required this.password,
    this.podiumEnabled = false,
    this.waiterEnabled = false,
    this.customerEnabled = false,
    this.banquetBookingEnabled = false,
    this.banquetReportsEnabled = false,
    this.queueReportsEnabled = false,
  });

  bool get isAdmin => username == 'admin';
}