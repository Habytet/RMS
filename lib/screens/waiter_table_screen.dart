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
      appBar: AppBar(
        title: const Text('Waiter Table Management'),
        actions: [
          if (isCorporate)
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
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Available Tables:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Expanded(
              child: tables.isEmpty
                  ? const Center(child: Text('No tables available'))
                  : GridView.builder(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                      ),
                      itemCount: tables.length,
                      itemBuilder: (context, index) {
                        final tableNumber = tables[index];
                        return Card(
                          child: InkWell(
                            onTap: () => _removeTable(tableNumber),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.table_restaurant, size: 40),
                                const SizedBox(height: 8),
                                Text(
                                  'Table $tableNumber',
                                  style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold),
                                ),
                                const Text('Tap to remove',
                                    style: TextStyle(
                                        fontSize: 12, color: Colors.grey)),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 16),
            const Text('Add New Table:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _tableController,
                    decoration: const InputDecoration(
                      labelText: 'Table Number',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: _addTable,
                  child: const Text('Add Table'),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Text('Customers Waiting:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Expanded(
              child: tokenProvider.queue.isEmpty
                  ? const Center(child: Text('No customers in queue'))
                  : ListView.builder(
                      itemCount: tokenProvider.queue.length,
                      itemBuilder: (context, index) {
                        final c = tokenProvider.queue[index];
                        final duration =
                            DateTime.now().difference(c.registeredAt);
                        final isLate = duration.inMinutes >= 15;
                        return Card(
                          shape: RoundedRectangleBorder(
                            side: BorderSide(
                              color: c.isCalled
                                  ? Colors.green
                                  : Colors.transparent,
                              width: 2,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          color: isLate ? Colors.red.shade400 : null,
                          child: ListTile(
                            title: Text(
                              '${c.name} (${c.pax} adults, ${c.children} kids)',
                              style: TextStyle(
                                  color: isLate ? Colors.white : null,
                                  fontWeight: FontWeight.bold),
                            ),
                            subtitle: Text(
                              'Token: ${c.token} | Waiting: ${duration.inMinutes} mins',
                              style: TextStyle(
                                  color: isLate ? Colors.white70 : null),
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

  void _removeTable(int tableNumber) {
    final tokenProvider = context.read<TokenProvider>();
    tokenProvider.removeTable(tableNumber);
  }

  void _addTable() {
    final text = _tableController.text.trim();
    final tableNum = int.tryParse(text);
    if (tableNum != null) {
      final tokenProvider = context.read<TokenProvider>();
      tokenProvider.addTable(tableNum);
      _tableController.clear();
    }
  }
}
