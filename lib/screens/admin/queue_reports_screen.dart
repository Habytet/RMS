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
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Colors.red.shade400,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.red.shade700,
              secondary: Colors.red.shade300,
              onSecondary: Colors.white,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: Colors.red.shade600,
              ),
            ),
            dialogTheme: DialogTheme(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              backgroundColor: Colors.white,
            ),
          ),
          child: child!,
        );
      },
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
      builder: (context) => AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.red.shade400),
            ),
            SizedBox(width: 16),
            Text('Generating Excel report...'),
          ],
        ),
      ),
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

  // Calculate statistics
  Map<String, dynamic> _calculateStats() {
    if (_customers.isEmpty) {
      return {
        'totalCustomers': 0,
        'avgWaitTime': 0,
        'totalPAX': 0,
        'avgPAX': 0,
      };
    }

    int totalWaitTime = 0;
    int customersWithWaitTime = 0;
    int totalPAX = 0;

    for (var customer in _customers) {
      if (customer.calledAt != null) {
        final waitTime =
            customer.calledAt!.difference(customer.registeredAt).inMinutes;
        totalWaitTime += waitTime;
        customersWithWaitTime++;
      }
      totalPAX += customer.pax;
    }

    return {
      'totalCustomers': _customers.length,
      'avgWaitTime': customersWithWaitTime > 0
          ? (totalWaitTime / customersWithWaitTime).round()
          : 0,
      'totalPAX': totalPAX,
      'avgPAX':
          (_customers.length > 0) ? (totalPAX / _customers.length).round() : 0,
    };
  }

  @override
  Widget build(BuildContext context) {
    // Get the branches list from the provider, just like your working AdminDisplayScreen
    final userProvider = context.watch<UserProvider>();
    final branches = userProvider.branches;
    final isAdmin = userProvider.currentUser?.isAdmin ?? false;
    final stats = _calculateStats();

    return Scaffold(
      appBar: AppBar(
        title: Text('Queue Reports'),
        backgroundColor: Colors.red.shade300,
        foregroundColor: Colors.white,
        elevation: 0,
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
        child: Column(
          children: [
            // Branch Selection
            Container(
              margin: EdgeInsets.all(16),
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.business, color: Colors.red.shade600),
                      SizedBox(width: 8),
                      Text(
                        'Select Branch',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.red.shade700,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _selectedBranchId,
                    hint: Text('Select a Branch to View Report'),
                    isExpanded: true,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            BorderSide(color: Colors.red.shade400, width: 2),
                      ),
                      prefixIcon:
                          Icon(Icons.location_on, color: Colors.red.shade400),
                    ),
                    items: [
                      DropdownMenuItem(
                        value: 'all',
                        child: Text('All Branches'),
                      ),
                      ...branches.map((branch) {
                        return DropdownMenuItem(
                          value: branch.id,
                          child: Text(branch.name),
                        );
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
                ],
              ),
            ),

            // Statistics Overview
            if (_selectedBranchId != null)
              Container(
                margin: EdgeInsets.symmetric(horizontal: 16),
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatCard(
                            'Total Customers',
                            stats['totalCustomers'].toString(),
                            Icons.people,
                            Colors.blue.shade100,
                            Colors.blue.shade600,
                          ),
                        ),
                        SizedBox(width: 16),
                        Expanded(
                          child: _buildStatCard(
                            'Avg Wait Time',
                            '${stats['avgWaitTime']} mins',
                            Icons.timer,
                            Colors.orange.shade100,
                            Colors.orange.shade600,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatCard(
                            'Total PAX',
                            stats['totalPAX'].toString(),
                            Icons.person_add,
                            Colors.green.shade100,
                            Colors.green.shade600,
                          ),
                        ),
                        SizedBox(width: 16),
                        Expanded(
                          child: _buildStatCard(
                            'Avg PAX',
                            stats['avgPAX'].toString(),
                            Icons.analytics,
                            Colors.purple.shade100,
                            Colors.purple.shade600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

            SizedBox(height: 16),

            // Date Range and Export Controls
            Container(
              margin: EdgeInsets.symmetric(horizontal: 16),
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.date_range, color: Colors.red.shade600),
                      SizedBox(width: 8),
                      Text(
                        'Report Controls',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.red.shade700,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed:
                              _selectedBranchId != null ? _pickRange : null,
                          icon: Icon(Icons.calendar_today,
                              size: 20, color: Colors.red.shade600),
                          label: Text(
                            _range == null
                                ? 'Pick Date Range'
                                : '${_fmt.format(_range!.start)}\n${_fmt.format(_range!.end)}',
                            style: TextStyle(fontSize: 12),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red.shade100,
                            foregroundColor: Colors.red.shade700,
                            padding: EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 12),
                      ElevatedButton.icon(
                        onPressed:
                            _customers.isNotEmpty ? _downloadExcel : null,
                        icon: Icon(Icons.download,
                            size: 20, color: Colors.green.shade600),
                        label: Text('Export Excel',
                            style: TextStyle(fontSize: 12)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.shade100,
                          foregroundColor: Colors.green.shade700,
                          padding: EdgeInsets.symmetric(
                              horizontal: 20, vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            SizedBox(height: 16),

            // Data Table
            Expanded(
              child: _isLoading
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.red.shade400),
                          ),
                          SizedBox(height: 16),
                          Text(
                            'Loading report data...',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    )
                  : _customers.isEmpty
                      ? Container(
                          margin: EdgeInsets.all(16),
                          padding: EdgeInsets.all(40),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 10,
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                _selectedBranchId == null
                                    ? Icons.business
                                    : Icons.analytics_outlined,
                                size: 64,
                                color: Colors.grey.shade400,
                              ),
                              SizedBox(height: 16),
                              Text(
                                _selectedBranchId == null
                                    ? 'Please select a branch'
                                    : 'No data for selected range',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.grey.shade600,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                _selectedBranchId == null
                                    ? 'Choose a branch to view queue reports'
                                    : 'Try adjusting your date range',
                                style: TextStyle(
                                  color: Colors.grey.shade500,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        )
                      : Container(
                          margin: EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 10,
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: SingleChildScrollView(
                              scrollDirection: Axis.vertical,
                              child: DataTable(
                                headingTextStyle: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red.shade700,
                                ),
                                dataTextStyle: TextStyle(
                                  color: Colors.grey.shade700,
                                ),
                                columns: [
                                  DataColumn(label: Text('Token')),
                                  DataColumn(label: Text('Customer Name')),
                                  if (_selectedBranchId == 'all')
                                    DataColumn(label: Text('Branch')),
                                  DataColumn(label: Text('PAX')),
                                  DataColumn(label: Text('Seated At')),
                                  DataColumn(label: Text('Wait Time')),
                                  DataColumn(label: Text('Operator')),
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
                                      DataCell(
                                          Text(customer.branchName ?? 'N/A')),
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
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon,
      Color bgColor, Color iconColor) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 28),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: iconColor,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
