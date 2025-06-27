// lib/screens/admin/queue_reports_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart'; // Import for checking Android version
import 'package:open_filex/open_filex.dart'; // Import for opening the file
import 'dart:io';

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
    _range =
        DateTimeRange(start: now.subtract(const Duration(days: 7)), end: now);

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
      List<Customer> allCustomers = [];

      if (_selectedBranchId == 'all') {
        // For "All" option, show a message that it's loading and fetch data in batches
        setState(() {
          _customers = [];
          _isLoading = true;
        });

        // Fetch data from all branches with a limit to avoid performance issues
        final branchesSnapshot = await FirebaseFirestore.instance
            .collection('branches')
            .where(FieldPath.documentId, isNotEqualTo: 'all')
            .limit(10) // Limit to prevent performance issues
            .get();

        for (var branchDoc in branchesSnapshot.docs) {
          final branchId = branchDoc.id;

          Query query = FirebaseFirestore.instance
              .collection('branches')
              .doc(branchId)
              .collection('completed')
              .orderBy('calledAt', descending: true)
              .limit(100); // Limit per branch to prevent performance issues

          // Apply date filters if they exist
          if (_range != null) {
            query =
                query.where('calledAt', isGreaterThanOrEqualTo: _range!.start);
            final endOfDay = DateTime(_range!.end.year, _range!.end.month,
                _range!.end.day, 23, 59, 59);
            query = query.where('calledAt', isLessThanOrEqualTo: endOfDay);
          }

          final snapshot = await query.get();
          final branchCustomers = snapshot.docs.map((doc) {
            final customer =
                Customer.fromMap(doc.data() as Map<String, dynamic>);
            customer.branchName =
                branchDoc.data()['name'] ?? branchId; // Set branch name
            return customer;
          }).toList();

          allCustomers.addAll(branchCustomers);
        }

        // Sort all customers by calledAt date
        allCustomers.sort((a, b) => (b.calledAt ?? DateTime.now())
            .compareTo(a.calledAt ?? DateTime.now()));
      } else {
        // Fetch data from specific branch
        Query query = FirebaseFirestore.instance
            .collection('branches')
            .doc(_selectedBranchId)
            .collection('completed')
            .orderBy('calledAt', descending: true)
            .limit(200); // Limit to prevent performance issues

        // Apply date filters if they exist
        if (_range != null) {
          query =
              query.where('calledAt', isGreaterThanOrEqualTo: _range!.start);
          final endOfDay = DateTime(
              _range!.end.year, _range!.end.month, _range!.end.day, 23, 59, 59);
          query = query.where('calledAt', isLessThanOrEqualTo: endOfDay);
        }

        final snapshot = await query.get();
        allCustomers = snapshot.docs
            .map((doc) => Customer.fromMap(doc.data() as Map<String, dynamic>))
            .toList();
      }

      if (mounted) {
        setState(() {
          _customers = allCustomers;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error: ${e.toString()}'),
              backgroundColor: Colors.red),
        );
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

  /// REVISED `_downloadExcel` function for modern Android compatibility
  Future<void> _downloadExcel() async {
    if (_customers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('No data to export'), backgroundColor: Colors.orange),
      );
      return;
    }

    // Show a loading indicator to the user
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      bool isGranted = false;
      // Scoped storage handling for different Android versions
      if (Platform.isAndroid) {
        final deviceInfo = await DeviceInfoPlugin().androidInfo;
        // For Android 12 (SDK 32) and below, we might need storage permission
        // For Android 13 (SDK 33) and above, permissions are handled per-media type
        // and not needed for saving to app's own directory.
        if (deviceInfo.version.sdkInt < 33) {
          final status = await Permission.storage.request();
          isGranted = status.isGranted;
        } else {
          // No explicit storage permission needed for Android 13+ to save to temp dir
          isGranted = true;
        }
      } else {
        // For iOS and other platforms
        isGranted = true;
      }

      if (!isGranted) {
        Navigator.pop(context); // Dismiss loading indicator
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Storage permission is required.'),
              backgroundColor: Colors.red),
        );
        return;
      }

      // Create Excel file
      final excel = Excel.createExcel();
      final sheet = excel['Queue Report'];

      // Add headers - **REMOVED 'const' from here**
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0))
          .value = TextCellValue('Token');
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: 0))
          .value = TextCellValue('Customer Name');
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: 0))
          .value = TextCellValue('Branch');
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: 0))
          .value = TextCellValue('PAX');
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: 0))
          .value = TextCellValue('Seated At');
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: 0))
          .value = TextCellValue('Wait Time (mins)');
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: 0))
          .value = TextCellValue('Called At');
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: 0))
          .value = TextCellValue('Operator');
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 8, rowIndex: 0))
          .value = TextCellValue('Waiter');

      // Add data
      for (int i = 0; i < _customers.length; i++) {
        final customer = _customers[i];
        final rowIndex = i + 1;
        final waitTime = customer.calledAt != null
            ? customer.calledAt!.difference(customer.registeredAt).inMinutes
            : 0;

        sheet
            .cell(
                CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex))
            .value = IntCellValue(customer.token);
        sheet
            .cell(
                CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex))
            .value = TextCellValue(customer.name);
        sheet
            .cell(
                CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: rowIndex))
            .value = TextCellValue(customer.branchName ?? 'N/A');
        sheet
            .cell(
                CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: rowIndex))
            .value = IntCellValue(customer.pax);
        sheet
                .cell(CellIndex.indexByColumnRow(
                    columnIndex: 4, rowIndex: rowIndex))
                .value =
            TextCellValue(
                DateFormat('dd/MM/yyyy HH:mm').format(customer.registeredAt));
        sheet
            .cell(
                CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: rowIndex))
            .value = IntCellValue(waitTime);
        sheet
            .cell(
                CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: rowIndex))
            .value = TextCellValue(customer.calledAt !=
                null
            ? DateFormat('dd/MM/yyyy HH:mm').format(customer.calledAt!)
            : 'N/A');
        sheet
            .cell(
                CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: rowIndex))
            .value = TextCellValue(customer.operator ?? 'N/A');
        sheet
            .cell(
                CellIndex.indexByColumnRow(columnIndex: 8, rowIndex: rowIndex))
            .value = TextCellValue(customer.waiterName ?? 'N/A');
      }

      // Save file to a temporary directory
      final directory = await getTemporaryDirectory();
      final startDate = _range?.start ?? DateTime.now();
      final endDate = _range?.end ?? DateTime.now();
      final fileName =
          'queue_report_${DateFormat('yyyyMMdd').format(startDate)}_to_${DateFormat('yyyyMMdd').format(endDate)}.xlsx';
      final filePath = '${directory.path}/$fileName';

      final fileBytes = excel.encode();
      if (fileBytes == null) {
        throw Exception("Failed to encode Excel file.");
      }
      final file = File(filePath);
      await file.writeAsBytes(fileBytes);

      Navigator.pop(context); // Dismiss loading indicator

      // Open the file using open_filex
      final result = await OpenFilex.open(filePath);
      if (result.type != ResultType.done) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open file: ${result.message}'),
            backgroundColor: Colors.red,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('File is ready. You can now save it to your device.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      Navigator.pop(context); // Dismiss loading indicator
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Error downloading file: ${e.toString()}'),
            backgroundColor: Colors.red),
      );
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
              items: [
                const DropdownMenuItem(
                    value: 'all', child: Text('All Branches')),
                ...branches.map((branch) {
                  return DropdownMenuItem(
                      value: branch.id, child: Text(branch.name));
                }).toList(),
              ],
              onChanged: isAdmin
                  ? (value) {
                      if (value != null) {
                        setState(() => _selectedBranchId = value);
                        _fetchReportData(); // Fetch data when a branch is selected
                      }
                    }
                  : null, // Dropdown is disabled for non-admins
            ),
          ),
          // Date picker and download buttons row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _selectedBranchId != null ? _pickRange : null,
                    icon: const Icon(Icons.calendar_today),
                    label: Text(_range == null
                        ? 'Pick Date Range'
                        : '${_fmt.format(_range!.start)} → ${_fmt.format(_range!.end)}'),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: _customers.isNotEmpty ? _downloadExcel : null,
                  icon: const Icon(Icons.download),
                  label: const Text('Download Excel'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          // UI to show loading indicator or the data table
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _customers.isEmpty
                    ? Center(
                        child: Text(_selectedBranchId == null
                            ? 'Please select a branch.'
                            : 'No data for selected range.'))
                    : SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          columns: [
                            const DataColumn(label: Text('Token')),
                            const DataColumn(label: Text('Customer Name')),
                            if (_selectedBranchId == 'all')
                              const DataColumn(label: Text('Branch')),
                            const DataColumn(label: Text('PAX')),
                            const DataColumn(label: Text('Seated At')),
                            const DataColumn(label: Text('Wait Time')),
                            const DataColumn(label: Text('Operator')),
                          ],
                          rows: _customers.map((customer) {
                            final waitTime = customer.calledAt != null
                                ? customer.calledAt!
                                    .difference(customer.registeredAt)
                                    .inMinutes
                                    .toString()
                                : '-';
                            return DataRow(cells: [
                              DataCell(Text('${customer.token}')),
                              DataCell(Text(customer.name)),
                              if (_selectedBranchId == 'all')
                                DataCell(Text(customer.branchName ?? 'N/A')),
                              DataCell(Text('${customer.pax}')),
                              DataCell(Text(customer.registeredAt != null
                                  ? DateFormat('dd MMM, HH:mm')
                                      .format(customer.registeredAt)
                                  : '-')),
                              DataCell(Text('$waitTime mins')),
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
