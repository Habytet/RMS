// lib/screens/podium_operator_screen.dart

import 'dart:async';
import 'package:flutter/material.dart'; // FIX: Corrected the import path
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher_string.dart';

import '../models/customer.dart';
import '../models/branch.dart';
import '../providers/token_provider.dart';
import '../providers/user_provider.dart';

class PodiumOperatorScreen extends StatefulWidget {
  @override
  State<PodiumOperatorScreen> createState() => _PodiumOperatorScreenState();
}

class _PodiumOperatorScreenState extends State<PodiumOperatorScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _paxController = TextEditingController();
  final _childrenController = TextEditingController();

  Timer? _timer;

  // --- Admin branch selection state ---
  String? _selectedBranchId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    // This timer will refresh the UI every second to update the waiting time
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _paxController.dispose();
    _childrenController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  void _registerCustomer({required bool isAdmin}) async {
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();
    final pax = int.tryParse(_paxController.text.trim()) ?? 0;
    final children = int.tryParse(_childrenController.text.trim()) ?? 0;
    if (name.isEmpty || phone.isEmpty || pax == 0) return;

    final operatorName =
        context.read<UserProvider>().currentUser?.email ?? 'Unknown';
    final tokenProvider = context.read<TokenProvider>();
    String? branchIdToUse;
    if (isAdmin) {
      branchIdToUse = _selectedBranchId;
      if (branchIdToUse == null || branchIdToUse == 'all') {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please select a branch.')));
        return;
      }
    }
    await tokenProvider.addCustomer(
      name,
      phone,
      pax,
      children,
      operatorName,
      branchIdOverride: isAdmin ? branchIdToUse : null,
    );

    _nameController.clear();
    _phoneController.clear();
    _paxController.clear();
    _childrenController.clear();
    FocusScope.of(context).unfocus();
    _tabController.animateTo(1);
    // Wait a moment and refresh UI
    await Future.delayed(const Duration(milliseconds: 500));
    setState(() {});
  }

  Future<void> _sendWhatsAppMessage(
      int token, String phone, String name) async {
    await context.read<TokenProvider>().markAsCalled(token);

    String sanitized = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (sanitized.length == 10) {
      sanitized = '91$sanitized';
    }
    final message = Uri.encodeComponent(
        "Hello $name, your table is ready. Your token is $token.");
    final url = "https://wa.me/$sanitized?text=$message";

    try {
      final success =
          await launchUrlString(url, mode: LaunchMode.externalApplication);
      if (!success) throw 'WhatsApp not available';
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Could not open WhatsApp.")),
        );
      }
    }
  }

  Future<void> _callCustomer(int token) async {
    final bool? confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Call'),
        content: const Text('Are you sure you want to call this customer?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('OK')),
        ],
      ),
    );

    if (confirm == true) {
      await context.read<TokenProvider>().markAsCalled(token);
    }
  }

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
    final tables = tokenProvider.availableTables;

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
        title: const Text('Podium Operator'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Register'),
            Tab(text: 'Call Customers'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Register Tab
          Padding(
            padding: const EdgeInsets.all(16),
            child: ListView(
              children: [
                if (isAdmin)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: DropdownButtonFormField<String>(
                      value: _selectedBranchId,
                      decoration: const InputDecoration(
                        labelText: 'Register to Branch',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        const DropdownMenuItem(
                            value: 'all',
                            child: Text('All Branches (Disabled)')),
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
                Text('Next Token: ${tokenProvider.nextToken}',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                TextField(
                    controller: _nameController,
                    decoration:
                        const InputDecoration(labelText: 'Customer Name')),
                TextField(
                    controller: _phoneController,
                    decoration: const InputDecoration(labelText: 'Phone'),
                    keyboardType: TextInputType.number),
                TextField(
                    controller: _paxController,
                    decoration:
                        const InputDecoration(labelText: 'No. of Adults'),
                    keyboardType: TextInputType.number),
                TextField(
                    controller: _childrenController,
                    decoration:
                        const InputDecoration(labelText: 'No. of Children'),
                    keyboardType: TextInputType.number),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => _registerCustomer(isAdmin: isAdmin),
                  child: const Text('Register Customer'),
                ),
              ],
            ),
          ),

          // Call Customers Tab
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Available Tables:',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                tables.isEmpty
                    ? const Text('No tables available',
                        style: TextStyle(color: Colors.grey))
                    : Wrap(
                        spacing: 8,
                        children: tables
                            .map((t) => Chip(
                                  label: Text('Table $t'),
                                  onDeleted: () => tokenProvider.removeTable(t),
                                ))
                            .toList(),
                      ),
                const SizedBox(height: 16),
                const Divider(),
                const Text('Customers Waiting:',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Expanded(
                  child: queue.isEmpty
                      ? const Center(child: Text('No customers in queue'))
                      : ListView.builder(
                          itemCount: queue.length,
                          itemBuilder: (context, index) {
                            final c = queue[index];
                            final duration =
                                DateTime.now().difference(c.registeredAt);
                            final isLate = duration.inMinutes >= 15;

                            return Dismissible(
                              key: ValueKey(c.token),
                              direction: DismissDirection.startToEnd,
                              onDismissed: (_) {
                                final waiterName = context
                                        .read<UserProvider>()
                                        .currentUser
                                        ?.username ??
                                    'Unknown';
                                context
                                    .read<TokenProvider>()
                                    .seatCustomer(c, waiterName);
                              },
                              background: Container(
                                color: Colors.blue,
                                alignment: Alignment.centerLeft,
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 20),
                                child: const Icon(Icons.login,
                                    color: Colors.white),
                              ),
                              child: Card(
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
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.message,
                                            color: Colors.green),
                                        onPressed: c.isCalled
                                            ? null
                                            : () => _sendWhatsAppMessage(
                                                c.token, c.phone, c.name),
                                      ),
                                      ElevatedButton(
                                        onPressed: c.isCalled
                                            ? null
                                            : () => _callCustomer(c.token),
                                        style: c.isCalled
                                            ? ElevatedButton.styleFrom(
                                                backgroundColor: Colors.grey)
                                            : null,
                                        child: Text(
                                            c.isCalled ? 'Called' : 'Call'),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
