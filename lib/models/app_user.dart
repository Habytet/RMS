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
  // --- NEW: Admin and Banquet Setup Permissions ---
  final bool banquetSetupEnabled;
  final bool userManagementEnabled;
  final bool menuManagementEnabled;
  final bool branchManagementEnabled;
  String? fcmToken;

  // NEW: Task-related permissions
  final bool canViewOwnTasks; // Made private to override with admin check
  final bool canSubmitTasks; // Made private to override with admin check
  final bool canViewStaffTasks; // Made private to override with admin check
  final bool canCreateTasks; // Made private to override with admin check
  final bool canEditAssignedTasks; // Made private to override with admin check
  final bool canReassignTasks; // Made private to override with admin check

  AppUser(
      {required this.username,
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
      // --- NEW: Add to constructor ---
      this.banquetSetupEnabled = false,
      this.userManagementEnabled = false,
      this.menuManagementEnabled = false,
      this.branchManagementEnabled = false,
      this.fcmToken,
      this.canViewOwnTasks = false,
      this.canSubmitTasks = false,
      this.canViewStaffTasks = false,
      this.canCreateTasks = false,
      this.canEditAssignedTasks = false,
      this.canReassignTasks = false});

  bool get isAdmin => username.toLowerCase() == 'admin';

  // // NEW: Public getters for task permissions that respect isAdmin status
  // @override
  // bool get canViewOwnTasks => isAdmin || _canViewOwnTasks;
  // @override
  // bool get canSubmitTasks => isAdmin || _canSubmitTasks;
  // @override
  // bool get canViewStaffTasks => isAdmin || _canViewStaffTasks;
  // @override
  // bool get canCreateTasks => isAdmin || _canCreateTasks;
  // @override
  // bool get canEditAssignedTasks => isAdmin || _canEditAssignedTasks;
  // @override
  // bool get canReassignTasks => isAdmin || _canReassignTasks;

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
      // --- NEW: Add to map ---
      'banquetSetupEnabled': banquetSetupEnabled,
      'userManagementEnabled': userManagementEnabled,
      'menuManagementEnabled': menuManagementEnabled,
      'branchManagementEnabled': branchManagementEnabled,
      // NEW: Task-related permissions (save the actual stored value, not the overridden one)
      'canViewOwnTasks': canViewOwnTasks,
      'canSubmitTasks': canSubmitTasks,
      'canViewStaffTasks': canViewStaffTasks,
      'canCreateTasks': canCreateTasks,
      'canEditAssignedTasks': canEditAssignedTasks,
      'canReassignTasks': canReassignTasks,
      'fcmToken': fcmToken
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
      // --- NEW: Read from map ---
      banquetSetupEnabled: map['banquetSetupEnabled'] ?? false,
      userManagementEnabled: map['userManagementEnabled'] ?? false,
      menuManagementEnabled: map['menuManagementEnabled'] ?? false,
      branchManagementEnabled: map['branchManagementEnabled'] ?? false,
      // NEW: Task-related permissions read from map
      canViewOwnTasks: map['canViewOwnTasks'] ?? false,
      canSubmitTasks: map['canSubmitTasks'] ?? false,
      canViewStaffTasks: map['canViewStaffTasks'] ?? false,
      canCreateTasks: map['canCreateTasks'] ?? false,
      canEditAssignedTasks: map['canEditAssignedTasks'] ?? false,
      canReassignTasks: map['canReassignTasks'] ?? false,
    );
  }
}
