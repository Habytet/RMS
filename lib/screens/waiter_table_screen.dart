// lib/screens/waiter_table_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/token_provider.dart';
import '../providers/user_provider.dart';
import '../models/branch.dart';

class WaiterTableScreen extends StatefulWidget {
  const WaiterTableScreen({super.key});

  @override
  State<WaiterTableScreen> createState() => _WaiterTableScreenState();
}

class _WaiterTableScreenState extends State<WaiterTableScreen> {
  final _tableController = TextEditingController();
  final _focusNode = FocusNode();
  Timer? _timer; // To refresh the waiting time display

  // --- Admin branch selection state ---
  String? _selectedBranchId;

  @override
  void initState() {
    super.initState();
    // This timer will refresh the UI every minute to update waiting times.
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _tableController.dispose();
    _focusNode.dispose();
    _timer?.cancel(); // Make sure to cancel the timer to prevent memory leaks.
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = context.watch<UserProvider>();
    final tokenProvider = context.watch<TokenProvider>();
    final isCorporate = userProvider.currentUser?.branchId == 'all';
    final List<Branch> allBranches = userProvider.branches;

    // For admins, use the tables from the selected branch, otherwise use the provider's tables
    final tables = tokenProvider.availableTables;
    final queue = tokenProvider.queue;

    // Set default branch for admin only once
    if (isCorporate && _selectedBranchId == null && allBranches.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _selectedBranchId = allBranches
                .firstWhere((b) => b.id != 'all',
                    orElse: () => allBranches.first)
                .id;
          });
        }
      });
    }

    // Update TokenProvider when admin selects a branch (only when changed)
    if (isCorporate &&
        _selectedBranchId != null &&
        _selectedBranchId != tokenProvider.adminSelectedBranchId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          tokenProvider.selectBranchForAdmin(_selectedBranchId!);
        }
      });
    }

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text(
          'Waiter Table Management',
          style: TextStyle(
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: Colors.red.shade300,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (isCorporate)
            Container(
              margin: EdgeInsets.only(right: 8),
              padding: EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: DropdownButton<String>(
                value: _selectedBranchId,
                dropdownColor: Colors.white,
                style:
                    TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
                underline: SizedBox(),
                items: [
                  DropdownMenuItem(
                    value: 'all',
                    child: Row(
                      children: [
                        Icon(Icons.all_inclusive,
                            color: Colors.white, size: 18),
                        SizedBox(width: 8),
                        Text('All Branches'),
                      ],
                    ),
                  ),
                  ...allBranches
                      .where((branch) => branch.id != 'all')
                      .map((branch) => DropdownMenuItem(
                            value: branch.id,
                            child: Row(
                              children: [
                                Icon(Icons.business,
                                    color: Colors.white, size: 18),
                                SizedBox(width: 8),
                                Text(branch.name),
                              ],
                            ),
                          )),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedBranchId = value;
                  });
                },
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
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // Statistics Section
              _buildStatisticsSection(tables, queue),

              SizedBox(height: 20),

              // Available Tables Section
              _buildAvailableTablesSection(tables),

              SizedBox(height: 20),

              // Add Table Section
              _buildAddTableSection(),

              SizedBox(height: 20),

              // Customers Waiting Section
              _buildCustomersWaitingSection(queue),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatisticsSection(List<int> tables, List<dynamic> queue) {
    final totalWaiting = queue.length;
    int totalAdults = 0;
    int totalChildren = 0;

    for (var customer in queue) {
      totalAdults += (customer.pax as int);
      totalChildren += (customer.children as int);
    }

    return Container(
      width: double.infinity,
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.table_restaurant,
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
                      'Restaurant Overview',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade800,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Manage tables and monitor customer queue',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Available Tables',
                  tables.length.toString(),
                  Icons.table_bar,
                  Colors.blue.shade100,
                  Colors.blue.shade600,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Customers Waiting',
                  totalWaiting.toString(),
                  Icons.people,
                  Colors.orange.shade100,
                  Colors.orange.shade600,
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Total Adults',
                  totalAdults.toString(),
                  Icons.person,
                  Colors.green.shade100,
                  Colors.green.shade600,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Total Children',
                  totalChildren.toString(),
                  Icons.child_care,
                  Colors.purple.shade100,
                  Colors.purple.shade600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon,
      Color bgColor, Color iconColor) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 20),
              Spacer(),
            ],
          ),
          SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade800,
            ),
          ),
          SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildAvailableTablesSection(List<int> tables) {
    return Container(
      width: double.infinity,
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.table_restaurant, color: Colors.red.shade400),
              SizedBox(width: 8),
              Text(
                'Available Tables',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.red.shade600,
                ),
              ),
              Spacer(),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.red.shade100,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  '${tables.length} tables',
                  style: TextStyle(
                    color: Colors.red.shade700,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          Container(
            height: 120,
            child: tables.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.table_restaurant_outlined,
                          size: 48,
                          color: Colors.grey.shade400,
                        ),
                        SizedBox(height: 8),
                        Text(
                          'No tables available',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  )
                : GridView.builder(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                      childAspectRatio: 1.2,
                    ),
                    itemCount: tables.length,
                    itemBuilder: (context, index) {
                      final tableNumber = tables[index];
                      return GestureDetector(
                        onTap: () => _removeTable(tableNumber),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.red.shade200,
                              width: 1,
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.table_restaurant,
                                size: 24,
                                color: Colors.red.shade600,
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Table $tableNumber',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red.shade700,
                                ),
                              ),
                              Text(
                                'Tap to remove',
                                style: TextStyle(
                                  fontSize: 8,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddTableSection() {
    return Container(
      width: double.infinity,
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.add_circle, color: Colors.red.shade400),
              SizedBox(width: 8),
              Text(
                'Add New Table',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.red.shade600,
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _tableController,
                  focusNode: _focusNode,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    hintText: 'Enter table number',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          BorderSide(color: Colors.red.shade400, width: 2),
                    ),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    prefixIcon: Icon(Icons.table_restaurant,
                        color: Colors.red.shade400),
                  ),
                ),
              ),
              SizedBox(width: 12),
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: LinearGradient(
                    colors: [Colors.red.shade400, Colors.red.shade600],
                  ),
                ),
                child: ElevatedButton(
                  onPressed: _addTable,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add, color: Colors.white, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Add',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCustomersWaitingSection(List queue) {
    return Expanded(
      child: Container(
        width: double.infinity,
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.people, color: Colors.red.shade400),
                SizedBox(width: 8),
                Text(
                  'Customers Waiting',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.red.shade600,
                  ),
                ),
                Spacer(),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.red.shade100,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    '${queue.length} customers',
                    style: TextStyle(
                      color: Colors.red.shade700,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            Expanded(
              child: queue.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.queue_music,
                            size: 64,
                            color: Colors.grey.shade400,
                          ),
                          SizedBox(height: 16),
                          Text(
                            'No customers waiting',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'The queue is currently empty',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: queue.length,
                      itemBuilder: (context, index) {
                        final c = queue[index];
                        final duration =
                            DateTime.now().difference(c.registeredAt);
                        final isLate = duration.inMinutes >= 15;

                        return Container(
                          margin: EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: isLate ? Colors.red.shade400 : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: c.isCalled
                                  ? Colors.green
                                  : Colors.transparent,
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 8,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: isLate
                                            ? Colors.white.withOpacity(0.2)
                                            : Colors.blue.shade100,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Icon(
                                        Icons.person,
                                        color: isLate
                                            ? Colors.white
                                            : Colors.blue.shade600,
                                        size: 20,
                                      ),
                                    ),
                                    SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            c.name,
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: isLate
                                                  ? Colors.white
                                                  : Colors.grey.shade800,
                                            ),
                                          ),
                                          SizedBox(height: 4),
                                          Text(
                                            'Token: ${c.token}',
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: isLate
                                                  ? Colors.white70
                                                  : Colors.grey.shade600,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: isLate
                                            ? Colors.white.withOpacity(0.2)
                                            : Colors.orange.shade100,
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: Text(
                                        '${duration.inMinutes} mins',
                                        style: TextStyle(
                                          color: isLate
                                              ? Colors.white
                                              : Colors.orange.shade700,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 12),
                                Row(
                                  children: [
                                    _buildInfoChip(
                                      '${c.pax} Adults',
                                      Icons.person,
                                      isLate
                                          ? Colors.white.withOpacity(0.2)
                                          : Colors.blue.shade100,
                                      isLate
                                          ? Colors.white
                                          : Colors.blue.shade600,
                                    ),
                                    SizedBox(width: 8),
                                    _buildInfoChip(
                                      '${c.children} Kids',
                                      Icons.child_care,
                                      isLate
                                          ? Colors.white.withOpacity(0.2)
                                          : Colors.orange.shade100,
                                      isLate
                                          ? Colors.white
                                          : Colors.orange.shade600,
                                    ),
                                    if (c.isCalled) ...[
                                      Spacer(),
                                      Container(
                                        padding: EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.green.shade100,
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.check_circle,
                                                size: 14,
                                                color: Colors.green.shade600),
                                            SizedBox(width: 4),
                                            Text(
                                              'Called',
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: Colors.green.shade600,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip(
      String label, IconData icon, Color bgColor, Color iconColor) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: iconColor),
          SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: iconColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  void _removeTable(int tableNumber) {
    final tokenProvider = context.read<TokenProvider>();
    tokenProvider.removeTable(tableNumber);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Table $tableNumber removed'),
        backgroundColor: Colors.orange.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  void _addTable() {
    final text = _tableController.text.trim();
    final tableNum = int.tryParse(text);
    if (tableNum != null && tableNum > 0) {
      final tokenProvider = context.read<TokenProvider>();
      tokenProvider.addTable(tableNum);
      _tableController.clear();
      _focusNode.unfocus();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Table $tableNum added successfully'),
          backgroundColor: Colors.green.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please enter a valid table number'),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      );
    }
  }
}
