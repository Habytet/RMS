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
  // --- NEW: Permission for the corporate admin display screen ---
  final bool adminDisplayEnabled;

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
    // --- NEW: Added to constructor with a default of false ---
    this.adminDisplayEnabled = false,
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
      // --- NEW: Added to the map for saving to Firestore ---
      'adminDisplayEnabled': adminDisplayEnabled,
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
      // --- NEW: Reads the new permission from Firestore ---
      adminDisplayEnabled: map['adminDisplayEnabled'] ?? false,
    );
  }
}
