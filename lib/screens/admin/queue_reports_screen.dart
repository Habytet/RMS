// lib/screens/admin/queue_reports_screen.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart'; // FIX: Corrected the import path

import '../../models/customer.dart';
import '../../providers/token_provider.dart';
import '../../providers/user_provider.dart';

class QueueReportsScreen extends StatefulWidget {
  @override
  State<QueueReportsScreen> createState() => _QueueReportsScreenState();
}

class _QueueReportsScreenState extends State<QueueReportsScreen> {
  DateTimeRange? _range;
  Future<List<Customer>>? _filteredDataFuture;

  final DateFormat _fmt = DateFormat('yyyy-MM-dd');
  final DateFormat _timeFmt = DateFormat('kk:mm');

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _range = DateTimeRange(start: now.subtract(const Duration(days: 7)), end: now);
    // Use a post-frame callback to safely access context
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  /// Efficiently loads data from Firestore using the provider
  void _loadData() {
    if (_range == null || !mounted) return;
    setState(() {
      _filteredDataFuture = context.read<TokenProvider>().fetchHistoryByDateRange(_range!);
    });
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
        _loadData(); // Reload data with the new range
      });
    }
  }

  Future<void> _exportToExcel(List<Customer> data) async {
    if (data.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No data to export.')),
      );
      return;
    }

    final excel = Excel.createExcel();
    final sheet = excel['Queue Report'];

    sheet.appendRow([
      TextCellValue('S.No'),
      TextCellValue('Customer Name'),
      TextCellValue('Number'),
      TextCellValue('Adults'),
      TextCellValue('Children'),
      TextCellValue('Registered At'),
      TextCellValue('Seated At'),
      TextCellValue('Wait Time (mins)'),
      TextCellValue('Token No'),
      TextCellValue('Podium Operator (Email)'),
    ]);

    for (int i = 0; i < data.length; i++) {
      final h = data[i];
      final waitTime = h.calledAt != null
          ? h.calledAt!.difference(h.registeredAt).inMinutes.toString()
          : '-';

      sheet.appendRow([
        TextCellValue('${i + 1}'),
        TextCellValue(h.name),
        TextCellValue(h.phone),
        TextCellValue('${h.pax}'),
        TextCellValue('${h.children}'),
        TextCellValue(_timeFmt.format(h.registeredAt)),
        TextCellValue(h.calledAt != null ? _timeFmt.format(h.calledAt!) : '-'),
        TextCellValue(waitTime),
        TextCellValue('${h.token}'),
        TextCellValue(h.operator ?? 'N/A'),
      ]);
    }

    final bytes = excel.save();
    if (bytes != null && mounted) {
      final dir = await getApplicationDocumentsDirectory();
      final filename = 'queue_report_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.xlsx';
      final file = File('${dir.path}/$filename');
      await file.writeAsBytes(bytes);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Exported to $filename'),
          action: SnackBarAction(
            label: 'Open',
            onPressed: () => OpenFilex.open(file.path),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Queue Reports'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: _pickRange,
                  icon: const Icon(Icons.calendar_today),
                  label: Text(
                    _range == null
                        ? 'Pick Date Range'
                        : '${_fmt.format(_range!.start)} → ${_fmt.format(_range!.end)}',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: FutureBuilder<List<Customer>>(
                future: _filteredDataFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(child: Text('An error occurred: ${snapshot.error}'));
                  }
                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return const Center(child: Text('No data for selected range.'));
                  }

                  final data = snapshot.data!;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () => _exportToExcel(data),
                        icon: const Icon(Icons.download),
                        label: const Text('Export Excel'),
                      ),
                      const SizedBox(height: 10),
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            columns: const [
                              DataColumn(label: Text('S.No')),
                              DataColumn(label: Text('Customer Name')),
                              DataColumn(label: Text('Number')),
                              DataColumn(label: Text('Adults')),
                              DataColumn(label: Text('Children')),
                              DataColumn(label: Text('Registered At')),
                              DataColumn(label: Text('Seated At')),
                              DataColumn(label: Text('Wait Time (mins)')),
                              DataColumn(label: Text('Token')),
                              DataColumn(label: Text('Podium Operator (Email)')),
                            ],
                            rows: List.generate(data.length, (i) {
                              final h = data[i];
                              final waitTime = h.calledAt != null
                                  ? h.calledAt!.difference(h.registeredAt).inMinutes.toString()
                                  : '-';

                              return DataRow(cells: [
                                DataCell(Text('${i + 1}')),
                                DataCell(Text(h.name)),
                                DataCell(Text(h.phone)),
                                DataCell(Text('${h.pax}')),
                                DataCell(Text('${h.children}')),
                                DataCell(Text(_timeFmt.format(h.registeredAt))),
                                DataCell(Text(h.calledAt != null ? _timeFmt.format(h.calledAt!) : '-')),
                                DataCell(Text(waitTime)),
                                DataCell(Text('${h.token}')),
                                DataCell(Text(h.operator ?? 'N/A')),
                              ]);
                            }),
                          ),
                        ),
                      ),
                    ],
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
