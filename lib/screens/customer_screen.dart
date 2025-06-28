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
      appBar: AppBar(
        title: const Text('Customer Display'),
        actions: [
          if (isAdmin)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: DropdownButton<String>(
                value: _selectedBranchId,
                items: [
                  const DropdownMenuItem(
                      value: 'all', child: Text('All Branches')),
                  ...allBranches
                      .where((branch) => branch.id != 'all')
                      .map((branch) => DropdownMenuItem(
                            value: branch.id,
                            child: Text(branch.name),
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
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.blue, Colors.purple],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              // Now Serving Section
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(30),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    const Text(
                      'NOW SERVING',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      nowServing?.toString() ?? '--',
                      style: const TextStyle(
                        fontSize: 72,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),

              // Queue Section
              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'QUEUE',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Expanded(
                        child: queue.isEmpty
                            ? const Center(
                                child: Text(
                                  'No customers waiting',
                                  style: TextStyle(
                                    fontSize: 18,
                                    color: Colors.grey,
                                  ),
                                ),
                              )
                            : GridView.builder(
                                gridDelegate:
                                    const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 3,
                                  crossAxisSpacing: 15,
                                  mainAxisSpacing: 15,
                                  childAspectRatio: 1.2,
                                ),
                                itemCount: queue.length,
                                itemBuilder: (context, index) {
                                  final customer = queue[index];
                                  return Container(
                                    decoration: BoxDecoration(
                                      color: customer.isCalled
                                          ? Colors.green.shade100
                                          : Colors.blue.shade100,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: customer.isCalled
                                            ? Colors.green
                                            : Colors.blue,
                                        width: 2,
                                      ),
                                    ),
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          '${customer.token}',
                                          style: TextStyle(
                                            fontSize: 32,
                                            fontWeight: FontWeight.bold,
                                            color: customer.isCalled
                                                ? Colors.green.shade800
                                                : Colors.blue.shade800,
                                          ),
                                        ),
                                        const SizedBox(height: 5),
                                        Text(
                                          customer.name,
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: customer.isCalled
                                                ? Colors.green.shade700
                                                : Colors.blue.shade700,
                                          ),
                                          textAlign: TextAlign.center,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        if (customer.isCalled)
                                          const Text(
                                            'CALLED',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.green,
                                            ),
                                          ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
