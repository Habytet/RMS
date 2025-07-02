// lib/screens/podium_operator_screen.dart

import 'dart:async';
import 'package:flutter/material.dart'; // FIX: Corrected the import path
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher_string.dart';

import '../models/customer.dart';
import '../models/branch.dart';
import '../providers/token_provider.dart';
import '../providers/user_provider.dart';
import '../models/table.dart';

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

  Future<void> _showTableSelectionDialog(Customer customer) async {
    final tokenProvider = context.read<TokenProvider>();
    final availableTables = tokenProvider.availableTables;

    if (availableTables.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No tables available. Please add tables first.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final int? selectedTable = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.table_restaurant, color: Colors.red.shade400),
            const SizedBox(width: 8),
            const Text('Select Table'),
          ],
        ),
        content: Container(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Assign table for ${customer.name}',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 16),
              Flexible(
                child: GridView.builder(
                  shrinkWrap: true,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                    childAspectRatio: 1.2,
                  ),
                  itemCount: availableTables.length,
                  itemBuilder: (context, index) {
                    final table = availableTables[index];
                    return GestureDetector(
                      onTap: () => Navigator.pop(context, table.number),
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
                              size: 20,
                              color: Colors.red.shade600,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Table ${table.number}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.red.shade700,
                              ),
                            ),
                            Text(
                              'Seat ${table.capacity}',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.red.shade600,
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
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );

    if (selectedTable != null) {
      try {
        await tokenProvider.assignTableToCustomer(customer, selectedTable);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${customer.name} assigned to Table $selectedTable'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to assign table: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = context.watch<UserProvider>();
    final tokenProvider = context.watch<TokenProvider>();
    final isAdmin = userProvider.currentUser?.isAdmin ?? false;
    final isCorporate = userProvider.currentUser?.branchId == 'all';
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
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          'Podium Operator',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 20,
          ),
        ),
        backgroundColor: Colors.red.shade400,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(
              icon: Icon(Icons.person_add),
              text: 'Register',
            ),
            Tab(
              icon: Icon(Icons.phone),
              text: 'Call Customers',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Register Tab
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Branch Selection for Corporate Users
                if (isCorporate)
                  Container(
                    margin: const EdgeInsets.only(bottom: 20),
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
                            Icon(Icons.business,
                                color: Colors.red.shade400, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'Branch Selection',
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
                            value: _selectedBranchId,
                            decoration: InputDecoration(
                              hintText: 'Select branch to register',
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 12),
                              suffixIcon: Icon(Icons.keyboard_arrow_down,
                                  color: Colors.grey.shade400),
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
                      ],
                    ),
                  ),

                // Next Token Display
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 20),
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
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade100,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.confirmation_number,
                              color: Colors.blue.shade600,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Next Token',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey.shade600,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${tokenProvider.nextToken}',
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey.shade800,
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

                // Registration Form
                Container(
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
                          Icon(Icons.person_add,
                              color: Colors.red.shade400, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Customer Registration',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Customer Name Field
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: TextField(
                          controller: _nameController,
                          decoration: InputDecoration(
                            labelText: 'Customer Name',
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                            prefixIcon:
                                Icon(Icons.person, color: Colors.grey.shade400),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Phone Field
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: TextField(
                          controller: _phoneController,
                          decoration: InputDecoration(
                            labelText: 'Phone Number',
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                            prefixIcon:
                                Icon(Icons.phone, color: Colors.grey.shade400),
                          ),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Adults and Children Row
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey.shade200),
                              ),
                              child: TextField(
                                controller: _paxController,
                                decoration: InputDecoration(
                                  labelText: 'Number of Adults',
                                  border: InputBorder.none,
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 12),
                                  prefixIcon: Icon(Icons.person,
                                      color: Colors.grey.shade400),
                                ),
                                keyboardType: TextInputType.number,
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey.shade200),
                              ),
                              child: TextField(
                                controller: _childrenController,
                                decoration: InputDecoration(
                                  labelText: 'Number of Children',
                                  border: InputBorder.none,
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 12),
                                  prefixIcon: Icon(Icons.child_care,
                                      color: Colors.grey.shade400),
                                ),
                                keyboardType: TextInputType.number,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Register Button
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: () => _registerCustomer(isAdmin: isAdmin),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red.shade400,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          child: const Text(
                            'Register Customer',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Call Customers Tab
          Column(
            children: [
              // Available Tables Section
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.table_restaurant,
                            color: Colors.red.shade400, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Available Tables',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    tables.isEmpty
                        ? Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.info_outline,
                                    color: Colors.grey.shade400),
                                const SizedBox(width: 8),
                                Text(
                                  'No tables available',
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: tables
                                .map((table) => Container(
                                      decoration: BoxDecoration(
                                        color: Colors.green.shade100,
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                            color: Colors.green.shade200),
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 12, vertical: 6),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.table_restaurant,
                                                color: Colors.green.shade600,
                                                size: 16),
                                            const SizedBox(width: 6),
                                            Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  'Table ${table.number}',
                                                  style: TextStyle(
                                                    color:
                                                        Colors.green.shade700,
                                                    fontWeight: FontWeight.w600,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                                Text(
                                                  'Seat ${table.capacity}',
                                                  style: TextStyle(
                                                    color:
                                                        Colors.green.shade600,
                                                    fontWeight: FontWeight.w500,
                                                    fontSize: 10,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(width: 4),
                                            GestureDetector(
                                              onTap: () => tokenProvider
                                                  .removeTable(table.number),
                                              child: Icon(Icons.close,
                                                  color: Colors.green.shade600,
                                                  size: 16),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ))
                                .toList(),
                          ),
                  ],
                ),
              ),

              // Customers Waiting Section
              Expanded(
                child: Container(
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
                          Icon(Icons.people,
                              color: Colors.red.shade400, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Customers Waiting',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade700,
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
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
                      const SizedBox(height: 16),
                      Expanded(
                        child: queue.isEmpty
                            ? Center(
                                child: Container(
                                  padding: const EdgeInsets.all(32),
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
                                          fontSize: 18,
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
                                itemCount: queue.length,
                                itemBuilder: (context, index) {
                                  final c = queue[index];
                                  final duration =
                                      DateTime.now().difference(c.registeredAt);
                                  final isLate = duration.inMinutes >= 15;

                                  return Dismissible(
                                    key: ValueKey(c.token),
                                    direction: DismissDirection.horizontal,
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
                                      margin: const EdgeInsets.only(bottom: 12),
                                      decoration: BoxDecoration(
                                        color: Colors.blue.shade400,
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      alignment: Alignment.centerLeft,
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 20),
                                      child: Row(
                                        children: [
                                          Icon(Icons.login,
                                              color: Colors.white),
                                          const SizedBox(width: 8),
                                          Text(
                                            'Seat Customer',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    secondaryBackground: Container(
                                      margin: const EdgeInsets.only(bottom: 12),
                                      decoration: BoxDecoration(
                                        color: Colors.orange.shade400,
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      alignment: Alignment.centerRight,
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 20),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.end,
                                        children: [
                                          Text(
                                            'Assign Table',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Icon(Icons.table_restaurant,
                                              color: Colors.white),
                                        ],
                                      ),
                                    ),
                                    confirmDismiss: (direction) async {
                                      if (direction ==
                                          DismissDirection.endToStart) {
                                        // Swipe left - show table selection
                                        await _showTableSelectionDialog(c);
                                        return false; // Don't dismiss the card
                                      }
                                      return true; // Allow swipe right to seat customer
                                    },
                                    child: Container(
                                      margin: const EdgeInsets.only(bottom: 12),
                                      decoration: BoxDecoration(
                                        color: isLate
                                            ? Colors.red.shade400
                                            : Colors.white,
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color: c.isCalled
                                              ? Colors.green
                                              : Colors.transparent,
                                          width: 2,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color:
                                                Colors.black.withOpacity(0.05),
                                            blurRadius: 8,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.all(20),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Container(
                                                  padding:
                                                      const EdgeInsets.all(8),
                                                  decoration: BoxDecoration(
                                                    color: isLate
                                                        ? Colors.white
                                                            .withOpacity(0.2)
                                                        : Colors.blue.shade100,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            8),
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
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Text(
                                                        c.name,
                                                        style: TextStyle(
                                                          fontSize: 16,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          color: isLate
                                                              ? Colors.white
                                                              : Colors.grey
                                                                  .shade800,
                                                        ),
                                                      ),
                                                      const SizedBox(height: 4),
                                                      Text(
                                                        'Token: ${c.token} | Waiting: ${duration.inMinutes} mins',
                                                        style: TextStyle(
                                                          fontSize: 14,
                                                          color: isLate
                                                              ? Colors.white70
                                                              : Colors.grey
                                                                  .shade600,
                                                          fontWeight:
                                                              FontWeight.w500,
                                                        ),
                                                      ),
                                                      if (c.assignedTableNumber !=
                                                          null) ...[
                                                        const SizedBox(
                                                            height: 2),
                                                        Text(
                                                          'Customer seated in - Table ${c.assignedTableNumber}',
                                                          style: TextStyle(
                                                            fontSize: 12,
                                                            color: isLate
                                                                ? Colors.white70
                                                                : Colors.green
                                                                    .shade600,
                                                            fontWeight:
                                                                FontWeight.w600,
                                                          ),
                                                        ),
                                                      ],
                                                    ],
                                                  ),
                                                ),
                                                if (isLate)
                                                  Container(
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                        horizontal: 8,
                                                        vertical: 4),
                                                    decoration: BoxDecoration(
                                                      color: Colors.white
                                                          .withOpacity(0.2),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              12),
                                                    ),
                                                    child: Text(
                                                      'LATE',
                                                      style: TextStyle(
                                                        color: Colors.white,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 10,
                                                      ),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                            const SizedBox(height: 12),
                                            Row(
                                              children: [
                                                _buildInfoChip(
                                                  '${c.pax} Adults',
                                                  Icons.person,
                                                  isLate
                                                      ? Colors.white
                                                          .withOpacity(0.2)
                                                      : Colors.blue.shade100,
                                                  isLate
                                                      ? Colors.white
                                                      : Colors.blue.shade600,
                                                ),
                                                const SizedBox(width: 8),
                                                _buildInfoChip(
                                                  '${c.children} Kids',
                                                  Icons.child_care,
                                                  isLate
                                                      ? Colors.white
                                                          .withOpacity(0.2)
                                                      : Colors.orange.shade100,
                                                  isLate
                                                      ? Colors.white
                                                      : Colors.orange.shade600,
                                                ),
                                                const Spacer(),
                                                Row(
                                                  children: [
                                                    Container(
                                                      decoration: BoxDecoration(
                                                        color: c.isCalled
                                                            ? Colors
                                                                .grey.shade300
                                                            : Colors
                                                                .green.shade100,
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(8),
                                                      ),
                                                      child: IconButton(
                                                        icon: Icon(
                                                          Icons.message,
                                                          color: c.isCalled
                                                              ? Colors
                                                                  .grey.shade500
                                                              : Colors.green
                                                                  .shade600,
                                                        ),
                                                        onPressed: c.isCalled
                                                            ? null
                                                            : () =>
                                                                _sendWhatsAppMessage(
                                                                    c.token,
                                                                    c.phone,
                                                                    c.name),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    SizedBox(
                                                      height: 40,
                                                      child: ElevatedButton(
                                                        onPressed: c.isCalled
                                                            ? null
                                                            : () =>
                                                                _callCustomer(
                                                                    c.token),
                                                        style: ElevatedButton
                                                            .styleFrom(
                                                          backgroundColor:
                                                              c.isCalled
                                                                  ? Colors.grey
                                                                      .shade300
                                                                  : Colors.red
                                                                      .shade400,
                                                          foregroundColor: c
                                                                  .isCalled
                                                              ? Colors
                                                                  .grey.shade500
                                                              : Colors.white,
                                                          shape:
                                                              RoundedRectangleBorder(
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        8),
                                                          ),
                                                          elevation: 0,
                                                        ),
                                                        child: Text(
                                                          c.isCalled
                                                              ? 'Called'
                                                              : 'Call',
                                                          style: TextStyle(
                                                            fontWeight:
                                                                FontWeight.w600,
                                                            fontSize: 12,
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
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
              ),
            ],
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
          Icon(
            icon,
            size: 14,
            color: iconColor,
          ),
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
