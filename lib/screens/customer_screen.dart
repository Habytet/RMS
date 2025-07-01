import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/token_provider.dart';
import '../providers/user_provider.dart';
import '../models/branch.dart';

class CustomerScreen extends StatefulWidget {
  @override
  State<CustomerScreen> createState() => _CustomerScreenState();
}

class _CustomerScreenState extends State<CustomerScreen> {
  // --- Admin branch selection state ---
  String? _selectedBranchId;

  @override
  Widget build(BuildContext context) {
    final userProvider = context.watch<UserProvider>();
    final tokenProvider = context.watch<TokenProvider>();
    final isAdmin = userProvider.currentUser?.isAdmin ?? false;
    final List<Branch> allBranches = userProvider.branches;

    // For admins, use the queue from the selected branch, otherwise use the provider's queue
    final queue =
        isAdmin && _selectedBranchId != null && _selectedBranchId != 'all'
            ? tokenProvider.queue
                .where((c) => c.branchName == _selectedBranchId)
                .toList()
            : tokenProvider.queue;
    final nowServing = tokenProvider.nowServing;

    // Set default branch for admin only once
    if (isAdmin && _selectedBranchId == null && allBranches.isNotEmpty) {
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
    if (isAdmin &&
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
          'Customer Display',
          style: TextStyle(
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: Colors.red.shade300,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (isAdmin)
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
              // Statistics Overview
              _buildStatisticsSection(queue, nowServing),

              SizedBox(height: 20),

              // Now Serving Section
              _buildNowServingSection(nowServing),

              SizedBox(height: 20),

              // Queue Section
              _buildQueueSection(queue),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatisticsSection(List queue, int? nowServing) {
    final totalWaiting = queue.length;
    final calledCustomers = queue.where((c) => c.isCalled).length;
    final waitingCustomers = totalWaiting - calledCustomers;

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
                  Icons.display_settings,
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
                      'Queue Status',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade800,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Real-time customer queue display',
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
                  'Now Serving',
                  nowServing?.toString() ?? '--',
                  Icons.restaurant,
                  Colors.green.shade100,
                  Colors.green.shade600,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Total Waiting',
                  totalWaiting.toString(),
                  Icons.people,
                  Colors.blue.shade100,
                  Colors.blue.shade600,
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Called',
                  calledCustomers.toString(),
                  Icons.check_circle,
                  Colors.orange.shade100,
                  Colors.orange.shade600,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Still Waiting',
                  waitingCustomers.toString(),
                  Icons.schedule,
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

  Widget _buildNowServingSection(int? nowServing) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(30),
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
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.restaurant,
                  color: Colors.green.shade600,
                  size: 24,
                ),
              ),
              SizedBox(width: 12),
              Text(
                'NOW SERVING',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade700,
                ),
              ),
            ],
          ),
          SizedBox(height: 20),
          Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.green.shade200,
                width: 2,
              ),
            ),
            child: Text(
              nowServing?.toString() ?? '--',
              style: TextStyle(
                fontSize: 72,
                fontWeight: FontWeight.bold,
                color: Colors.green.shade700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQueueSection(List queue) {
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
                Icon(Icons.queue, color: Colors.red.shade400),
                SizedBox(width: 8),
                Text(
                  'CUSTOMER QUEUE',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
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
            SizedBox(height: 20),
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
                  : GridView.builder(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 1.1,
                      ),
                      itemCount: queue.length,
                      itemBuilder: (context, index) {
                        final customer = queue[index];
                        return Container(
                          decoration: BoxDecoration(
                            color: customer.isCalled
                                ? Colors.green.shade50
                                : Colors.red.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: customer.isCalled
                                  ? Colors.green.shade300
                                  : Colors.red.shade300,
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
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: customer.isCalled
                                      ? Colors.green.shade100
                                      : Colors.red.shade100,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  Icons.person,
                                  color: customer.isCalled
                                      ? Colors.green.shade600
                                      : Colors.red.shade600,
                                  size: 20,
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                '${customer.token}',
                                style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: customer.isCalled
                                      ? Colors.green.shade700
                                      : Colors.red.shade700,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                customer.name,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: customer.isCalled
                                      ? Colors.green.shade600
                                      : Colors.red.shade600,
                                  fontWeight: FontWeight.w500,
                                ),
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (customer.isCalled) ...[
                                SizedBox(height: 4),
                                Container(
                                  padding: EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.green.shade100,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    'CALLED',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green.shade700,
                                    ),
                                  ),
                                ),
                              ],
                            ],
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
}
