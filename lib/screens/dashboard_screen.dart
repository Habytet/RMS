import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import '../models/app_user.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    _slideAnimation = Tween<Offset>(
      begin: Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return 'Good Morning';
    } else if (hour < 17) {
      return 'Good Afternoon';
    } else {
      return 'Good Evening';
    }
  }

  @override
  Widget build(BuildContext context) {
    final authStatus = context.watch<UserProvider>().authStatus;
    final user = context.read<UserProvider>().currentUser;

    if (authStatus == AuthStatus.unauthenticated) {
      return Scaffold(
        appBar: AppBar(
          title: Text('Dashboard'),
          backgroundColor: Colors.red.shade300,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.red.shade50,
                Colors.white,
              ],
            ),
          ),
          child: Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.red.shade400),
            ),
          ),
        ),
      );
    }
    if (authStatus == AuthStatus.unknown || user == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text('Dashboard'),
          backgroundColor: Colors.red.shade300,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.red.shade50,
                Colors.white,
              ],
            ),
          ),
          child: Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.red.shade400),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Dashboard',
          style: TextStyle(
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: Colors.red.shade300,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          Container(
            margin: EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: IconButton(
              icon: Icon(Icons.logout, color: Colors.white),
              onPressed: () => context.read<UserProvider>().logout(),
            ),
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.red.shade50,
              Colors.white,
            ],
          ),
        ),
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Greeting Section
                  _buildGreetingSection(user),
                  SizedBox(height: 24),

                  // Statistics Cards - Only visible to super admin (branchId: 'all')
                  if (user.branchId == 'all') ...[
                    _buildStatisticsSection(),
                    SizedBox(height: 24),
                  ],

                  // Quick Actions - Only visible to super admin (branchId: 'all')
                  if (user.branchId == 'all') ...[
                    _buildQuickActionsSection(user),
                    SizedBox(height: 24),
                  ],

                  // Module Cards
                  _buildModuleCardsSection(user),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGreetingSection(AppUser user) {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.waving_hand,
              color: Colors.red.shade600,
              size: 24,
            ),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _getGreeting(),
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.red.shade700,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  user.username,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Welcome back to your dashboard',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.person,
              color: Colors.red.shade400,
              size: 20,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatisticsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Today\'s Overview',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.red.shade600,
          ),
        ),
        SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'Customers Waiting',
                '12',
                Icons.people,
                Colors.blue.shade100,
                Colors.blue.shade600,
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                'Bookings Today',
                '8',
                Icons.event,
                Colors.green.shade100,
                Colors.green.shade600,
              ),
            ),
          ],
        ),
        SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'Active Tasks',
                '5',
                Icons.assignment,
                Colors.orange.shade100,
                Colors.orange.shade600,
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                'Revenue Today',
                '₹45,200',
                Icons.trending_up,
                Colors.purple.shade100,
                Colors.purple.shade600,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon,
      Color bgColor, Color iconColor) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  color: iconColor,
                  size: 20,
                ),
              ),
              Spacer(),
              Icon(
                Icons.trending_up,
                color: Colors.green.shade400,
                size: 16,
              ),
            ],
          ),
          SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade800,
            ),
          ),
          SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionsSection(AppUser user) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Actions',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.red.shade600,
          ),
        ),
        SizedBox(height: 12),
        Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: _buildQuickActionButton(
                  'New Booking',
                  Icons.add_circle_outline,
                  Colors.green.shade100,
                  Colors.green.shade600,
                  () {
                    if (user.banquetBookingEnabled || user.isAdmin) {
                      Navigator.pushNamed(context, '/banquet');
                    }
                  },
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: _buildQuickActionButton(
                  'View Tasks',
                  Icons.assignment_outlined,
                  Colors.blue.shade100,
                  Colors.blue.shade600,
                  () {
                    if (user.canViewOwnTasks || user.isAdmin) {
                      Navigator.pushNamed(context, '/tasks/branch_manager');
                    }
                  },
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: _buildQuickActionButton(
                  'Reports',
                  Icons.analytics_outlined,
                  Colors.purple.shade100,
                  Colors.purple.shade600,
                  () {
                    if (user.queueReportsEnabled || user.isAdmin) {
                      Navigator.pushNamed(context, '/admin/queue_reports');
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActionButton(String label, IconData icon, Color bgColor,
      Color iconColor, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: iconColor,
              size: 24,
            ),
            SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: iconColor,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModuleCardsSection(AppUser user) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Modules',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.red.shade600,
          ),
        ),
        SizedBox(height: 12),
        GridView.count(
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.2,
          children: [
            if (user.podiumEnabled ||
                user.waiterEnabled ||
                user.customerEnabled ||
                user.adminDisplayEnabled ||
                user.isAdmin)
              _buildModernModuleCard(
                context,
                'Queue',
                Icons.people,
                Colors.blue.shade100,
                Colors.blue.shade600,
                'Queue management',
                () => _openQueueModule(context, user),
              ),
            if (user.banquetBookingEnabled ||
                user.banquetSetupEnabled ||
                user.banquetReportsEnabled ||
                user.chefDisplayEnabled ||
                user.isAdmin)
              _buildModernModuleCard(
                context,
                'Banquet',
                Icons.apartment,
                Colors.green.shade100,
                Colors.green.shade600,
                'Booking management',
                () => _openBanquetModule(context, user),
              ),
            if (user.canViewOwnTasks || user.canViewStaffTasks || user.isAdmin)
              _buildModernModuleCard(
                context,
                'Tasks',
                Icons.assignment,
                Colors.orange.shade100,
                Colors.orange.shade600,
                'Task tracking',
                () => _openTasksModule(context, user),
              ),
            if (user.queueReportsEnabled ||
                user.banquetReportsEnabled ||
                user.isAdmin)
              _buildModernModuleCard(
                context,
                'Reports',
                Icons.bar_chart,
                Colors.purple.shade100,
                Colors.purple.shade600,
                'Analytics and reports',
                () => _openReportsModule(context, user),
              ),
            if (user.isAdmin || user.canViewStaffTasks)
              _buildModernModuleCard(
                context,
                'Notifications',
                Icons.notifications,
                Colors.red.shade100,
                Colors.red.shade600,
                'System notifications',
                () => _openNotificationsModule(context, user),
              ),
            if (user.userManagementEnabled ||
                user.menuManagementEnabled ||
                user.branchManagementEnabled ||
                user.isAdmin)
              _buildModernModuleCard(
                context,
                'Admin',
                Icons.admin_panel_settings,
                Colors.indigo.shade100,
                Colors.indigo.shade600,
                'Administrative settings',
                () => _openAdminModule(context, user),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildModernModuleCard(
    BuildContext context,
    String label,
    IconData icon,
    Color bgColor,
    Color iconColor,
    String description,
    VoidCallback onTap,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    color: iconColor,
                    size: 24,
                  ),
                ),
                SizedBox(height: 12),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade800,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                Spacer(),
                Row(
                  children: [
                    Text(
                      'Tap to open',
                      style: TextStyle(
                        fontSize: 10,
                        color: iconColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Spacer(),
                    Icon(
                      Icons.arrow_forward_ios,
                      color: iconColor,
                      size: 12,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openQueueModule(BuildContext context, AppUser user) {
    final items = <Map<String, String>>[];
    if (user.adminDisplayEnabled) {
      items.add({'title': 'Admin Display', 'route': '/queue/admin_display'});
    }
    if (user.podiumEnabled)
      items.add({'title': 'Podium Operator', 'route': '/podium'});
    if (user.waiterEnabled) items.add({'title': 'Waiter', 'route': '/waiter'});
    if (user.customerEnabled)
      items.add({'title': 'Customer Display', 'route': '/customer'});
    if (user.todaysViewEnabled || user.isAdmin)
      items.add({'title': "Today's View", 'route': '/todays_view'});
    _openSubMenu(context, 'Queue Module', items);
  }

  void _openBanquetModule(BuildContext context, AppUser user) {
    final items = <Map<String, String>>[];
    if (user.banquetBookingEnabled || user.isAdmin)
      items.add({'title': 'Banquet Booking', 'route': '/banquet'});
    if (user.banquetSetupEnabled || user.isAdmin)
      items.add({'title': 'Banquet Setup', 'route': '/banquet/setup'});
    if (user.banquetReportsEnabled || user.isAdmin)
      items.add({'title': 'View Bookings', 'route': '/banquet/bookings'});
    if (user.chefDisplayEnabled || user.isAdmin)
      items.add({'title': 'Chef Display', 'route': '/banquet/chef_display'});
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
    if (user.queueReportsEnabled || user.isAdmin)
      items.add({'title': 'Queue Reports', 'route': '/admin/queue_reports'});
    if (user.banquetReportsEnabled || user.isAdmin)
      items
          .add({'title': 'Banquet Reports', 'route': '/admin/banquet_reports'});
    _openSubMenu(context, 'Reports', items);
  }

  void _openNotificationsModule(BuildContext context, AppUser user) {
    final items = <Map<String, String>>[];
    if (user.isAdmin || user.canViewStaffTasks)
      items.add({'title': 'Notifications', 'route': '/notifications'});
    _openSubMenu(context, 'Notifications', items);
  }

  void _openAdminModule(BuildContext context, AppUser user) {
    final items = <Map<String, String>>[];
    if (user.userManagementEnabled || user.isAdmin)
      items.add({'title': 'User Management', 'route': '/admin/users'});
    if (user.menuManagementEnabled || user.isAdmin)
      items.add({'title': 'Menu Management', 'route': '/admin/menus'});
    if (user.branchManagementEnabled || user.isAdmin)
      items.add({'title': 'Branch Management', 'route': '/admin/branches'});
    _openSubMenu(context, 'Admin Module', items);
  }

  void _openSubMenu(
      BuildContext context, String title, List<Map<String, String>> items) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
              offset: Offset(0, -5),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.menu, color: Colors.red.shade400),
                      SizedBox(width: 8),
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.red.shade600,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  ...items
                      .map((i) => Container(
                            margin: EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: ListTile(
                              title: Text(
                                i['title']!,
                                style: TextStyle(
                                  fontWeight: FontWeight.w500,
                                  color: Colors.grey.shade800,
                                ),
                              ),
                              trailing: Icon(
                                Icons.arrow_forward_ios,
                                color: Colors.red.shade400,
                                size: 16,
                              ),
                              onTap: () {
                                Navigator.pop(context);
                                Navigator.pushNamed(context, i['route']!);
                              },
                            ),
                          ))
                      .toList(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
