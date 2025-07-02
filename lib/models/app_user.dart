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
  // --- NEW: Today's View Permission ---
  final bool todaysViewEnabled;
  // --- NEW: Admin and Banquet Setup Permissions ---
  final bool banquetSetupEnabled;
  // --- NEW: Chef Display Permission ---
  final bool chefDisplayEnabled;
  final bool userManagementEnabled;
  final bool menuManagementEnabled;
  final bool branchManagementEnabled;
  // NEW: Task-related permissions
  final bool _canViewOwnTasks;
  final bool _canSubmitTasks;
  final bool _canViewStaffTasks;
  final bool _canCreateTasks;
  final bool _canEditAssignedTasks;
  final bool _canReassignTasks;
  String? fcmToken;

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
      // --- NEW: Today's View Permission ---
      this.todaysViewEnabled = false,
      // --- NEW: Add to constructor ---
      this.banquetSetupEnabled = false,
      // --- NEW: Chef Display Permission ---
      this.chefDisplayEnabled = false,
      this.userManagementEnabled = false,
      this.menuManagementEnabled = false,
      this.branchManagementEnabled = false,
      // NEW: Task-related permissions
      bool canViewOwnTasks = false,
      bool canSubmitTasks = false,
      bool canViewStaffTasks = false,
      bool canCreateTasks = false,
      bool canEditAssignedTasks = false,
      bool canReassignTasks = false,
      this.fcmToken})
      : _canViewOwnTasks = canViewOwnTasks,
        _canSubmitTasks = canSubmitTasks,
        _canViewStaffTasks = canViewStaffTasks,
        _canCreateTasks = canCreateTasks,
        _canEditAssignedTasks = canEditAssignedTasks,
        _canReassignTasks = canReassignTasks;

  bool get isAdmin => username.toLowerCase() == 'admin';

  // NEW: Public getters for task permissions that respect isAdmin status
  bool get canViewOwnTasks => isAdmin || _canViewOwnTasks;
  bool get canSubmitTasks => isAdmin || _canSubmitTasks;
  bool get canViewStaffTasks => isAdmin || _canViewStaffTasks;
  bool get canCreateTasks => isAdmin || _canCreateTasks;
  bool get canEditAssignedTasks => isAdmin || _canEditAssignedTasks;
  bool get canReassignTasks => isAdmin || _canReassignTasks;

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
      // --- NEW: Today's View Permission ---
      'todaysViewEnabled': todaysViewEnabled,
      // --- NEW: Add to map ---
      'banquetSetupEnabled': banquetSetupEnabled,
      // --- NEW: Chef Display Permission ---
      'chefDisplayEnabled': chefDisplayEnabled,
      'userManagementEnabled': userManagementEnabled,
      'menuManagementEnabled': menuManagementEnabled,
      'branchManagementEnabled': branchManagementEnabled,
      // NEW: Task-related permissions (save the actual stored value, not the overridden one)
      'canViewOwnTasks': _canViewOwnTasks,
      'canSubmitTasks': _canSubmitTasks,
      'canViewStaffTasks': _canViewStaffTasks,
      'canCreateTasks': _canCreateTasks,
      'canEditAssignedTasks': _canEditAssignedTasks,
      'canReassignTasks': _canReassignTasks,
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
      // --- NEW: Today's View Permission ---
      todaysViewEnabled: map['todaysViewEnabled'] ?? false,
      // --- NEW: Read from map ---
      banquetSetupEnabled: map['banquetSetupEnabled'] ?? false,
      // --- NEW: Chef Display Permission ---
      chefDisplayEnabled: map['chefDisplayEnabled'] ?? false,
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
      fcmToken: map['fcmToken'],
    );
  }
}
