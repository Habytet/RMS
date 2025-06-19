// lib/models/app_user.dart

class AppUser {
  final String username;
  final String email;
  final String branchId;
  final bool podiumEnabled;
  final bool waiterEnabled;
  final bool customerEnabled;
  final bool banquetBookingEnabled;
  final bool banquetReportsEnabled;
  final bool queueReportsEnabled;

  AppUser({
    required this.username,
    required this.email,
    required this.branchId,
    this.podiumEnabled = false,
    this.waiterEnabled = false,
    this.customerEnabled = false,
    this.banquetBookingEnabled = false,
    this.banquetReportsEnabled = false,
    this.queueReportsEnabled = false,
  });

  bool get isAdmin => username.toLowerCase() == 'admin';

  Map<String, dynamic> toMap() {
    return {
      'username': username,
      'email': email,
      'branchId': branchId,
      'podiumEnabled': podiumEnabled,
      'waiterEnabled': waiterEnabled,
      'customerEnabled': customerEnabled,
      'banquetBookingEnabled': banquetBookingEnabled,
      'banquetReportsEnabled': banquetReportsEnabled,
      'queueReportsEnabled': queueReportsEnabled,
    };
  }

  factory AppUser.fromMap(Map<String, dynamic> map) {
    return AppUser(
      username: map['username'] ?? '',
      email: map['email'] ?? '',
      branchId: map['branchId'] ?? 'all',
      podiumEnabled: map['podiumEnabled'] ?? false,
      waiterEnabled: map['waiterEnabled'] ?? false,
      customerEnabled: map['customerEnabled'] ?? false,
      banquetBookingEnabled: map['banquetBookingEnabled'] ?? false,
      banquetReportsEnabled: map['banquetReportsEnabled'] ?? false,
      queueReportsEnabled: map['queueReportsEnabled'] ?? false,
    );
  }
}