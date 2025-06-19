import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import '../../models/customer.dart';

class ReportsScreen extends StatefulWidget {
  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  DateTime? fromDate;
  DateTime? toDate;
  List<Customer> filtered = [];

  void _filterData() {
    final box = Hive.box<Customer>('completedQueue');
    final all = box.values.toList();
    setState(() {
      filtered = all.where((c) {
        final dt = c.calledAt ?? DateTime.now();
        return (fromDate == null || dt.isAfter(fromDate!.subtract(Duration(days: 1)))) &&
            (toDate == null || dt.isBefore(toDate!.add(Duration(days: 1))));
      }).toList()
        ..sort((a, b) => b.calledAt!.compareTo(a.calledAt!));
    });
  }

  Future<void> _exportToExcel() async {
    final excel = Excel.createExcel();
    final sheet = excel['Report'];

    final headers = [
      'S.No', 'Customer Name', 'Number', 'Entered Time',
      'Seated Time', 'Waited Time', 'Date', 'Podium Operator', 'Waiter'
    ];
    sheet.appendRow(headers.map((h) => TextCellValue(h)).toList());

    final dateFmt = DateFormat('yyyy-MM-dd HH:mm');
    for (var i = 0; i < filtered.length; i++) {
      final c = filtered[i];
      final entered = dateFmt.format(c.registeredAt);
      final seated = dateFmt.format(c.calledAt!);
      final waited = c.calledAt!.difference(c.registeredAt);
      final waitedStr = '${waited.inMinutes}m ${waited.inSeconds % 60}s';
      final dateOnly = DateFormat('yyyy-MM-dd').format(c.calledAt!);
      final row = [
        '${i + 1}', c.name, c.phone, entered, seated, waitedStr, dateOnly, 'N/A', 'N/A'
      ];
      sheet.appendRow(row.map((v) => TextCellValue(v)).toList());
    }

    final fileBytes = excel.encode()!;
    final directory = await getExternalStorageDirectory();
    final fileName = 'report_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.xlsx';
    final file = File('${directory!.path}/$fileName');
    await file.writeAsBytes(fileBytes);

    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Exported to ${file.path}'))
    );
  }

  Future<void> _pickDate({required bool isFrom}) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: isFrom ? fromDate ?? now : toDate ?? now,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 2),
    );
    if (picked != null) {
      setState(() {
        if (isFrom) fromDate = picked;
        else toDate = picked;
      });
      _filterData();
    }
  }

  @override
  void initState() {
    super.initState();
    _filterData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Reports'),
        actions: [
          IconButton(
              onPressed: filtered.isEmpty ? null : _exportToExcel,
              icon: Icon(Icons.download)
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                Expanded(child: _dateButton('From', fromDate, () => _pickDate(isFrom: true))),
                SizedBox(width: 10),
                Expanded(child: _dateButton('To', toDate, () => _pickDate(isFrom: false))),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: [
                  DataColumn(label: Text('S.No')),
                  DataColumn(label: Text('Name')),
                  DataColumn(label: Text('Number')),
                  DataColumn(label: Text('Entered')),
                  DataColumn(label: Text('Seated')),
                  DataColumn(label: Text('Waited')),
                  DataColumn(label: Text('Date')),
                  DataColumn(label: Text('Podium')),
                  DataColumn(label: Text('Waiter')),
                ],
                rows: List.generate(filtered.length, (i) {
                  final c = filtered[i];
                  final waited = c.calledAt!.difference(c.registeredAt);
                  return DataRow(cells: [
                    DataCell(Text('${i + 1}')),
                    DataCell(Text(c.name)),
                    DataCell(Text(c.phone)),
                    DataCell(Text(DateFormat('HH:mm').format(c.registeredAt))),
                    DataCell(Text(DateFormat('HH:mm').format(c.calledAt!))),
                    DataCell(Text('${waited.inMinutes}m')),
                    DataCell(Text(DateFormat('yyyy-MM-dd').format(c.calledAt!))),
                    DataCell(Text('N/A')),
                    DataCell(Text('N/A')),
                  ]);
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dateButton(String label, DateTime? date, VoidCallback onTap) {
    final text = date != null ? DateFormat('yyyy-MM-dd').format(date) : label;
    return ElevatedButton(onPressed: onTap, child: Text(text));
  }
}