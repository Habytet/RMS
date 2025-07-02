// lib/screens/todays_view_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/token_provider.dart';
import '../providers/user_provider.dart';
import '../models/customer.dart';
import '../models/branch.dart';

class TodaysViewScreen extends StatefulWidget {
  const TodaysViewScreen({super.key});

  @override
  State<TodaysViewScreen> createState() => _TodaysViewScreenState();
}

class _TodaysViewScreenState extends State<TodaysViewScreen> {
  Timer? _timer;
  String? _selectedBranchId;
  List<Customer> _todaysCustomers = [];
  bool _isLoading = true;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeScreen();
    });
  }

  void _initializeScreen() {
    if (_isInitialized || !mounted) return;

    final userProvider = context.read<UserProvider>();
    final isCorporate = userProvider.currentUser?.branchId == 'all';
    final List<Branch> allBranches = userProvider.branches;

    if (isCorporate && allBranches.isNotEmpty) {
      // Set default branch for corporate users
      final defaultBranch = allBranches.firstWhere((b) => b.id != 'all',
          orElse: () => allBranches.first);
      _selectedBranchId = defaultBranch.id;
    } else if (!isCorporate) {
      // For non-corporate users, use their assigned branch
      _selectedBranchId = userProvider.currentUser?.branchId;
    }

    _isInitialized = true;
    _loadTodaysCustomers();

    // Start timer only after initialization
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) {
        _loadTodaysCustomers();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _loadTodaysCustomers() async {
    if (!_isInitialized) return;

    try {
      setState(() {
        _isLoading = true;
      });

      final tokenProvider = context.read<TokenProvider>();
      final userProvider = context.read<UserProvider>();
      final isCorporate = userProvider.currentUser?.branchId == 'all';

      String? branchIdToUse;
      if (isCorporate) {
        branchIdToUse = _selectedBranchId;
      } else {
        branchIdToUse = userProvider.currentUser?.branchId;
      }

      if (branchIdToUse == null || branchIdToUse == 'all') {
        setState(() {
          _todaysCustomers = [];
          _isLoading = false;
        });
        return;
      }

      final customers = await tokenProvider.getTodaysCustomers(branchIdToUse);
      if (mounted) {
        setState(() {
          _todaysCustomers = customers;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading today\'s customers: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = context.read<UserProvider>();
    final isCorporate = userProvider.currentUser?.branchId == 'all';
    final List<Branch> allBranches = userProvider.branches;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          "Today's View",
          style: TextStyle(
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: Colors.red.shade400,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (isCorporate)
            Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: DropdownButton<String>(
                value: _selectedBranchId,
                dropdownColor: Colors.white,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
                underline: const SizedBox(),
                items: [
                  const DropdownMenuItem(
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
                                const SizedBox(width: 8),
                                Text(branch.name),
                              ],
                            ),
                          )),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedBranchId = value;
                  });
                  if (value != null && value != 'all') {
                    _loadTodaysCustomers();
                  }
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
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(),
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // Statistics Section
                    _buildStatisticsSection(_todaysCustomers),
                    const SizedBox(height: 20),

                    // Today's Customers Section
                    _buildTodaysCustomersSection(_todaysCustomers),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildStatisticsSection(List<Customer> todaysCustomers) {
    final totalCustomers = todaysCustomers.length;
    int totalAdults = 0;
    int totalChildren = 0;
    int calledCustomers = 0;
    int seatedCustomers = 0;

    for (var customer in todaysCustomers) {
      totalAdults += customer.pax;
      totalChildren += customer.children;
      if (customer.isCalled) calledCustomers++;
      if (customer.assignedTableNumber != null) seatedCustomers++;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.today, color: Colors.red.shade400, size: 20),
              const SizedBox(width: 8),
              Text(
                "Today's Statistics",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Total Customers',
                  totalCustomers.toString(),
                  Icons.people,
                  Colors.blue.shade100,
                  Colors.blue.shade600,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Called',
                  calledCustomers.toString(),
                  Icons.phone,
                  Colors.green.shade100,
                  Colors.green.shade600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Seated',
                  seatedCustomers.toString(),
                  Icons.table_restaurant,
                  Colors.orange.shade100,
                  Colors.orange.shade600,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Total Guests',
                  (totalAdults + totalChildren).toString(),
                  Icons.person,
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: iconColor,
                  ),
                ),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    color: iconColor.withOpacity(0.8),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTodaysCustomersSection(List<Customer> todaysCustomers) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.list_alt, color: Colors.red.shade400, size: 20),
              const SizedBox(width: 8),
              Text(
                "Today's Customers",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade700,
                ),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.red.shade100,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  '${todaysCustomers.length} customers',
                  style: TextStyle(
                    color: Colors.red.shade700,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          todaysCustomers.isEmpty
              ? Center(
                  child: Container(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.today,
                          size: 64,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No customers today',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'No customers have been registered today',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: todaysCustomers.length,
                  itemBuilder: (context, index) {
                    final customer = todaysCustomers[index];
                    final duration =
                        DateTime.now().difference(customer.registeredAt);
                    final isLate = duration.inMinutes >= 15;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: isLate ? Colors.red.shade400 : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: customer.isCalled
                              ? Colors.green
                              : Colors.transparent,
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
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
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        customer.name,
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: isLate
                                              ? Colors.white
                                              : Colors.grey.shade800,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Token: ${customer.token}',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: isLate
                                              ? Colors.white70
                                              : Colors.grey.shade600,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      if (customer.assignedTableNumber !=
                                          null) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          'Seated at Table ${customer.assignedTableNumber}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: isLate
                                                ? Colors.white70
                                                : Colors.green.shade600,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
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
                                    const SizedBox(height: 4),
                                    Text(
                                      '${customer.registeredAt.hour.toString().padLeft(2, '0')}:${customer.registeredAt.minute.toString().padLeft(2, '0')}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: isLate
                                            ? Colors.white70
                                            : Colors.grey.shade500,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                _buildInfoChip(
                                  '${customer.pax} Adults',
                                  Icons.person,
                                  isLate
                                      ? Colors.white.withOpacity(0.2)
                                      : Colors.blue.shade100,
                                  isLate ? Colors.white : Colors.blue.shade600,
                                ),
                                const SizedBox(width: 8),
                                _buildInfoChip(
                                  '${customer.children} Kids',
                                  Icons.child_care,
                                  isLate
                                      ? Colors.white.withOpacity(0.2)
                                      : Colors.orange.shade100,
                                  isLate
                                      ? Colors.white
                                      : Colors.orange.shade600,
                                ),
                                const Spacer(),
                                if (customer.isCalled)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.green.shade100,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.check_circle,
                                            size: 14,
                                            color: Colors.green.shade600),
                                        const SizedBox(width: 4),
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
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(
      String label, IconData icon, Color bgColor, Color iconColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: iconColor),
          const SizedBox(width: 4),
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
}
