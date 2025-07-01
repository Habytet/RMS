import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/token_provider.dart';
import '../../providers/user_provider.dart';
import '../../models/customer.dart';
import '../../models/branch.dart';

class AdminDisplayScreen extends StatefulWidget {
  const AdminDisplayScreen({super.key});

  @override
  State<AdminDisplayScreen> createState() => _AdminDisplayScreenState();
}

class _AdminDisplayScreenState extends State<AdminDisplayScreen> {
  String _selectedBranchFilter = 'all';

  @override
  Widget build(BuildContext context) {
    final UserProvider userProvider = context.watch<UserProvider>();
    final TokenProvider tokenProvider = context.watch<TokenProvider>();

    final isCorporate = userProvider.currentUser?.branchId == 'all';
    final List<Branch> allBranches = userProvider.branches;
    final List<Customer> queue = tokenProvider.queue;
    final bool isLoading = tokenProvider.isLoading;

    final List<Customer> filteredQueue = _selectedBranchFilter == 'all'
        ? queue
        : queue.where((c) => c.branchName == _selectedBranchFilter).toList();

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          'Queue Management',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 20,
          ),
        ),
        backgroundColor: Colors.red.shade400,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Statistics Section
          Container(
            margin: const EdgeInsets.all(16),
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
            child: Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    'Total Waiting',
                    filteredQueue.length.toString(),
                    Icons.people,
                    Colors.blue.shade100,
                    Colors.blue.shade600,
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: _buildStatItem(
                    'Total Adults',
                    filteredQueue.fold(0, (sum, c) => sum + c.pax).toString(),
                    Icons.person,
                    Colors.green.shade100,
                    Colors.green.shade600,
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: _buildStatItem(
                    'Total Kids',
                    filteredQueue
                        .fold(0, (sum, c) => sum + c.children)
                        .toString(),
                    Icons.child_care,
                    Colors.orange.shade100,
                    Colors.orange.shade600,
                  ),
                ),
              ],
            ),
          ),

          // Branch Filter Section
          if (isCorporate)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
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
                      Icon(Icons.filter_list,
                          color: Colors.red.shade400, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Filter by Branch',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: DropdownButtonFormField<String>(
                      value: _selectedBranchFilter,
                      decoration: InputDecoration(
                        hintText: 'Select branch to filter',
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        suffixIcon: Icon(Icons.keyboard_arrow_down,
                            color: Colors.grey.shade400),
                      ),
                      items: [
                        DropdownMenuItem(
                          value: 'all',
                          child: Row(
                            children: [
                              Icon(Icons.all_inclusive,
                                  color: Colors.red.shade400, size: 18),
                              const SizedBox(width: 8),
                              const Text('All Branches'),
                            ],
                          ),
                        ),
                        ...allBranches
                            .where((branch) => branch.id != 'all')
                            .map((branch) {
                          return DropdownMenuItem(
                            value: branch.id,
                            child: Row(
                              children: [
                                Icon(Icons.business,
                                    color: Colors.red.shade400, size: 18),
                                const SizedBox(width: 8),
                                Text(branch.name),
                              ],
                            ),
                          );
                        }),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _selectedBranchFilter = value;
                          });
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 8),

          // Queue List Section
          Expanded(
            child: isLoading
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.red.shade400),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Loading queue data...',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  )
                : filteredQueue.isEmpty
                    ? Center(
                        child: Container(
                          margin: const EdgeInsets.all(32),
                          padding: const EdgeInsets.all(32),
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
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.queue_music,
                                size: 64,
                                color: Colors.grey.shade400,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No customers waiting',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'The queue is currently empty',
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
                        padding: const EdgeInsets.all(16),
                        itemCount: filteredQueue.length,
                        itemBuilder: (context, index) {
                          final customer = filteredQueue[index];

                          final String branchId = customer.branchName ?? '';
                          final branchName = allBranches
                              .firstWhere((branch) => branch.id == branchId,
                                  orElse: () => Branch(id: '', name: 'Unknown'))
                              .name;

                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: Colors.blue.shade100,
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: Icon(
                                          Icons.person,
                                          color: Colors.blue.shade600,
                                          size: 24,
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              customer.name,
                                              style: TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.grey.shade800,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              'Token: ${customer.token}',
                                              style: TextStyle(
                                                fontSize: 14,
                                                color: Colors.grey.shade600,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.green.shade100,
                                          borderRadius:
                                              BorderRadius.circular(20),
                                        ),
                                        child: Text(
                                          branchName,
                                          style: TextStyle(
                                            color: Colors.green.shade700,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  Row(
                                    children: [
                                      _buildInfoChip(
                                        '${customer.pax} Adults',
                                        Icons.person,
                                        Colors.blue.shade100,
                                        Colors.blue.shade600,
                                      ),
                                      const SizedBox(width: 12),
                                      _buildInfoChip(
                                        '${customer.children} Kids',
                                        Icons.child_care,
                                        Colors.orange.shade100,
                                        Colors.orange.shade600,
                                      ),
                                      const Spacer(),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.grey.shade100,
                                          borderRadius:
                                              BorderRadius.circular(20),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.phone,
                                              size: 16,
                                              color: Colors.grey.shade600,
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              customer.phone,
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey.shade600,
                                                fontWeight: FontWeight.w500,
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
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String title, String value, IconData icon,
      Color bgColor, Color iconColor) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
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
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          title,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildInfoChip(
      String label, IconData icon, Color bgColor, Color iconColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: iconColor,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: iconColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
