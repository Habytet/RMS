import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:open_filex/open_filex.dart';
import 'dart:io';

import '../../models/banquet_booking.dart';
import '../../providers/user_provider.dart';

class BanquetReportsScreen extends StatefulWidget {
  const BanquetReportsScreen({super.key});

  @override
  State<BanquetReportsScreen> createState() => _BanquetReportsScreenState();
}

class _BanquetReportsScreenState extends State<BanquetReportsScreen> {
  // State variables to hold user selections and data
  String? _selectedBranchId;
  DateTimeRange? _range;
  List<BanquetBooking> _bookings = [];
  bool _isLoading = false;

  final DateFormat _fmt = DateFormat('yyyy-MM-dd');

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _range =
        DateTimeRange(start: now.subtract(const Duration(days: 30)), end: now);

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

  // Fetch banquet booking data
  Future<void> _fetchReportData() async {
    if (_selectedBranchId == null || _selectedBranchId!.isEmpty) {
      setState(() => _bookings = []);
      return;
    }
    setState(() => _isLoading = true);

    try {
      List<BanquetBooking> allBookings = [];

      if (_selectedBranchId == 'all') {
        setState(() {
          _bookings = [];
          _isLoading = true;
        });

        // Fetch data from all branches
        final branchesSnapshot = await FirebaseFirestore.instance
            .collection('branches')
            .where(FieldPath.documentId, isNotEqualTo: 'all')
            .limit(10)
            .get();

        for (var branchDoc in branchesSnapshot.docs) {
          final branchId = branchDoc.id;

          Query query = FirebaseFirestore.instance
              .collection('branches')
              .doc(branchId)
              .collection('banquetBookings')
              .orderBy('date', descending: true)
              .limit(100);

          // Apply date filters if they exist
          if (_range != null) {
            query = query.where('date', isGreaterThanOrEqualTo: _range!.start);
            final endOfDay = DateTime(_range!.end.year, _range!.end.month,
                _range!.end.day, 23, 59, 59);
            query = query.where('date', isLessThanOrEqualTo: endOfDay);
          }

          final snapshot = await query.get();
          final branchBookings = snapshot.docs.map((doc) {
            final booking =
                BanquetBooking.fromMap(doc.data() as Map<String, dynamic>);
            return booking;
          }).toList();

          allBookings.addAll(branchBookings);
        }

        // Sort all bookings by date
        allBookings.sort((a, b) => b.date.compareTo(a.date));
      } else {
        // Fetch data from specific branch
        Query query = FirebaseFirestore.instance
            .collection('branches')
            .doc(_selectedBranchId)
            .collection('banquetBookings')
            .orderBy('date', descending: true)
            .limit(200);

        // Apply date filters if they exist
        if (_range != null) {
          query = query.where('date', isGreaterThanOrEqualTo: _range!.start);
          final endOfDay = DateTime(
              _range!.end.year, _range!.end.month, _range!.end.day, 23, 59, 59);
          query = query.where('date', isLessThanOrEqualTo: endOfDay);
        }

        final snapshot = await query.get();
        allBookings = snapshot.docs
            .map((doc) =>
                BanquetBooking.fromMap(doc.data() as Map<String, dynamic>))
            .toList();
      }

      if (mounted) {
        setState(() {
          _bookings = allBookings;
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
      lastDate: DateTime.now().add(const Duration(days: 365)),
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
      _fetchReportData();
    }
  }

  Future<void> _downloadExcel() async {
    if (_bookings.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('No data to export'), backgroundColor: Colors.orange),
      );
      return;
    }

    try {
      setState(() => _isLoading = true);

      // Create Excel workbook
      final excel = Excel.createExcel();
      final sheet = excel['Banquet Reports'];

      // Add headers
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0))
          .value = TextCellValue('Date');
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: 0))
          .value = TextCellValue('Customer Name');
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: 0))
          .value = TextCellValue('Phone');
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: 0))
          .value = TextCellValue('Hall');
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: 0))
          .value = TextCellValue('Slot');
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: 0))
          .value = TextCellValue('Guests');
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: 0))
          .value = TextCellValue('Total Amount');
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: 0))
          .value = TextCellValue('Status');

      // Add data
      for (int i = 0; i < _bookings.length; i++) {
        final booking = _bookings[i];
        final row = i + 1;

        sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row))
            .value = TextCellValue(_fmt.format(booking.date));
        sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row))
            .value = TextCellValue(booking.customerName);
        sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: row))
            .value = TextCellValue(booking.phone);
        sheet
                .cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: row))
                .value =
            TextCellValue(
                booking.hallSlots.map((hs) => hs['hallName'] ?? '').join(', '));
        sheet
                .cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: row))
                .value =
            TextCellValue(booking.hallSlots
                .map((hs) => hs['slotLabel'] ?? '')
                .join(', '));
        sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: row))
            .value = IntCellValue(booking.pax);
        sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: row))
            .value = DoubleCellValue(booking.totalAmount);
        sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: row))
            .value = TextCellValue(booking.isDraft ? 'Draft' : 'Confirmed');
      }

      // Get directory and save file
      final directory = await getApplicationDocumentsDirectory();
      final fileName =
          'banquet_reports_${_fmt.format(_range!.start)}_${_fmt.format(_range!.end)}.xlsx';
      final file = File('${directory.path}/$fileName');
      await file.writeAsBytes(excel.encode()!);

      // Open file
      await OpenFilex.open(file.path);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Report exported successfully'),
              backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error exporting: ${e.toString()}'),
              backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = context.watch<UserProvider>();
    final isAdmin = userProvider.currentUser?.isAdmin ?? false;
    final branches = userProvider.branches;

    // Calculate statistics
    final totalBookings = _bookings.length;
    final confirmedBookings = _bookings.where((b) => !b.isDraft).length;
    final draftBookings = _bookings.where((b) => b.isDraft).length;
    final totalRevenue =
        _bookings.fold<double>(0, (sum, b) => sum + b.totalAmount);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Banquet Reports'),
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
            // Branch Selection (for admin users)
            if (isAdmin)
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: DropdownButtonFormField<String>(
                  value: _selectedBranchId,
                  decoration: InputDecoration(
                    labelText: 'Select Branch',
                    labelStyle: TextStyle(color: Colors.red.shade400),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.red.shade200),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.red.shade200),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide:
                          BorderSide(color: Colors.red.shade400, width: 2),
                    ),
                    filled: true,
                    fillColor: Colors.red.shade50,
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: 'all',
                      child: Text('All Branches'),
                    ),
                    ...branches
                        .where((b) => b.id != 'all')
                        .map((b) => DropdownMenuItem(
                              value: b.id,
                              child: Text(b.name),
                            ))
                        .toList(),
                  ],
                  onChanged: (value) {
                    if (value != null && value != _selectedBranchId) {
                      setState(() {
                        _selectedBranchId = value;
                      });
                      _fetchReportData();
                    }
                  },
                ),
              ),

            // Statistics Overview
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          'Total Bookings',
                          totalBookings.toString(),
                          Icons.event,
                          Colors.blue.shade100,
                          Colors.blue.shade600,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildStatCard(
                          'Confirmed',
                          confirmedBookings.toString(),
                          Icons.check_circle,
                          Colors.green.shade100,
                          Colors.green.shade600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          'Drafts',
                          draftBookings.toString(),
                          Icons.edit_note,
                          Colors.orange.shade100,
                          Colors.orange.shade600,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildStatCard(
                          'Revenue',
                          '${totalRevenue.toStringAsFixed(0)}',
                          Icons.attach_money,
                          Colors.purple.shade100,
                          Colors.purple.shade600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Date Range and Export Controls
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
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
                    child: ElevatedButton.icon(
                      onPressed: _pickRange,
                      icon: Icon(Icons.calendar_today,
                          size: 18, color: Colors.red.shade600),
                      label: Text(
                        _range == null
                            ? 'Pick Date Range'
                            : '${_fmt.format(_range!.start)}\n${_fmt.format(_range!.end)}',
                        style: const TextStyle(fontSize: 12),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade100,
                        foregroundColor: Colors.red.shade700,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: _isLoading ? null : _downloadExcel,
                    icon: _isLoading
                        ? SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.red.shade600),
                            ),
                          )
                        : Icon(Icons.download,
                            size: 18, color: Colors.red.shade600),
                    label: Text(
                      _isLoading ? 'Exporting...' : 'Export',
                      style: const TextStyle(fontSize: 12),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade100,
                      foregroundColor: Colors.red.shade700,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Data Table
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(),
                      )
                    : _bookings.isEmpty
                        ? const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.event_busy,
                                    size: 64, color: Colors.grey),
                                SizedBox(height: 16),
                                Text(
                                  'No banquet bookings found',
                                  style: TextStyle(
                                    fontSize: 18,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: SingleChildScrollView(
                              child: DataTable(
                                headingTextStyle: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red.shade700,
                                ),
                                columns: const [
                                  DataColumn(label: Text('Date')),
                                  DataColumn(label: Text('Customer')),
                                  DataColumn(label: Text('Phone')),
                                  DataColumn(label: Text('Hall')),
                                  DataColumn(label: Text('Slot')),
                                  DataColumn(label: Text('Guests')),
                                  DataColumn(label: Text('Amount')),
                                  DataColumn(label: Text('Status')),
                                ],
                                rows: _bookings.map((booking) {
                                  return DataRow(
                                    cells: [
                                      DataCell(Text(_fmt.format(booking.date))),
                                      DataCell(Text(booking.customerName)),
                                      DataCell(Text(booking.phone)),
                                      DataCell(Text(booking.hallSlots
                                          .map((hs) => hs['hallName'] ?? '')
                                          .join(', '))),
                                      DataCell(Text(booking.hallSlots
                                          .map((hs) => hs['slotLabel'] ?? '')
                                          .join(', '))),
                                      DataCell(Text(booking.pax.toString())),
                                      DataCell(Text(
                                          '${booking.totalAmount.toStringAsFixed(0)}')),
                                      DataCell(
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: booking.isDraft
                                                ? Colors.orange.shade100
                                                : Colors.green.shade100,
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                          child: Text(
                                            booking.isDraft
                                                ? 'Draft'
                                                : 'Confirmed',
                                            style: TextStyle(
                                              color: booking.isDraft
                                                  ? Colors.orange.shade800
                                                  : Colors.green.shade800,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  );
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
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 28),
          const SizedBox(width: 12),
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
                const SizedBox(height: 2),
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
