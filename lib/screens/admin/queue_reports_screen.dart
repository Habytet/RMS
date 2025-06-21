// lib/screens/admin/queue_reports_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/customer.dart';
import '../../providers/user_provider.dart';

class QueueReportsScreen extends StatefulWidget {
  const QueueReportsScreen({super.key});

  @override
  State<QueueReportsScreen> createState() => _QueueReportsScreenState();
}

class _QueueReportsScreenState extends State<QueueReportsScreen> {
  // State variables to hold user selections and data
  String? _selectedBranchId;
  DateTimeRange? _range;
  List<Customer> _customers = [];
  bool _isLoading = false;

  final DateFormat _fmt = DateFormat('yyyy-MM-dd');

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _range = DateTimeRange(start: now.subtract(const Duration(days: 7)), end: now);

    // For non-admins, automatically select their branch and try to load data
    final userProvider = context.read<UserProvider>();
    if (!(userProvider.currentUser?.isAdmin ?? false)) {
      _selectedBranchId = userProvider.currentBranchId;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _fetchReportData();
        }
      });
    }
  }

  // This function now performs a SIMPLE query on a specific branch path
  Future<void> _fetchReportData() async {
    // Don't do anything if no branch is selected.
    if (_selectedBranchId == null || _selectedBranchId!.isEmpty) {
      setState(() => _customers = []);
      return;
    }
    setState(() => _isLoading = true);

    try {
      // Build a simple query that does NOT need a complex index.
      // This is the key to fixing the "failed-precondition" error.
      Query query = FirebaseFirestore.instance
          .collection('branches')
          .doc(_selectedBranchId)
          .collection('completed')
          .orderBy('calledAt', descending: true); // Sort by date

      // Apply date filters if they exist
      if (_range != null) {
        query = query.where('calledAt', isGreaterThanOrEqualTo: _range!.start);
        final endOfDay = DateTime(_range!.end.year, _range!.end.month, _range!.end.day, 23, 59, 59);
        query = query.where('calledAt', isLessThanOrEqualTo: endOfDay);
      }

      final snapshot = await query.get();
      final fetchedCustomers = snapshot.docs
          .map((doc) => Customer.fromMap(doc.data() as Map<String, dynamic>))
          .toList();

      if (mounted) {
        setState(() {
          _customers = fetchedCustomers;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _pickRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      initialDateRange: _range,
    );
    if (picked != null) {
      setState(() {
        _range = picked;
      });
      _fetchReportData(); // Reload data when date changes
    }
  }

  @override
  Widget build(BuildContext context) {
    // Get the branches list from the provider, just like your working AdminDisplayScreen
    final userProvider = context.watch<UserProvider>();
    final branches = userProvider.branches;
    final isAdmin = userProvider.currentUser?.isAdmin ?? false;

    return Scaffold(
      appBar: AppBar(title: const Text('Queue Reports')),
      body: Column(
        children: [
          // This is the dropdown logic from your working screen
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: DropdownButtonFormField<String>(
              value: _selectedBranchId,
              hint: const Text('Select a Branch to View Report'),
              isExpanded: true,
              decoration: const InputDecoration(border: OutlineInputBorder()),
              items: branches.map((branch) {
                return DropdownMenuItem(value: branch.id, child: Text(branch.name));
              }).toList(),
              onChanged: isAdmin ? (value) {
                if (value != null) {
                  setState(() => _selectedBranchId = value);
                  _fetchReportData(); // Fetch data when a branch is selected
                }
              } : null, // Dropdown is disabled for non-admins
            ),
          ),
          // Date picker button
          ElevatedButton.icon(
            onPressed: _selectedBranchId != null ? _pickRange : null,
            icon: const Icon(Icons.calendar_today),
            label: Text(_range == null ? 'Pick Date Range' : '${_fmt.format(_range!.start)} → ${_fmt.format(_range!.end)}'),
          ),
          const SizedBox(height: 10),
          // UI to show loading indicator or the data table
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _customers.isEmpty
                ? Center(child: Text(_selectedBranchId == null ? 'Please select a branch.' : 'No data for selected range.'))
                : SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Customer Name')),
                  DataColumn(label: Text('Wait Time')),
                  DataColumn(label: Text('Called At')),
                  DataColumn(label: Text('Token')),
                  DataColumn(label: Text('Operator')),
                ],
                rows: _customers.map((customer) {
                  final waitTime = customer.calledAt != null
                      ? customer.calledAt!.difference(customer.registeredAt).inMinutes.toString()
                      : '-';
                  return DataRow(cells: [
                    DataCell(Text(customer.name)),
                    DataCell(Text('$waitTime mins')),
                    DataCell(Text(customer.calledAt != null ? DateFormat('dd MMM, HH:mm').format(customer.calledAt!) : '-')),
                    DataCell(Text('${customer.token}')),
                    DataCell(Text(customer.operator ?? 'N/A')),
                  ]);
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
