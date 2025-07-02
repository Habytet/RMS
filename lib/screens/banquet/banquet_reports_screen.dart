import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import '../../models/banquet_booking.dart';

class BanquetReportsScreen extends StatefulWidget {
  @override
  State<BanquetReportsScreen> createState() => _BanquetReportsScreenState();
}

class _BanquetReportsScreenState extends State<BanquetReportsScreen> {
  DateTime? fromDate;
  DateTime? toDate;
  List<BanquetBooking> filtered = [];

  void _filterData() {
    final box = Hive.box<BanquetBooking>('banquetBookings');
    final all = box.values.toList();
    setState(() {
      filtered = all.where((b) {
        final d = b.date;
        return (fromDate == null || !d.isBefore(fromDate!)) &&
            (toDate == null || !d.isAfter(toDate!));
      }).toList()
        ..sort((a, b) => b.date.compareTo(a.date));
    });
  }

  Future<void> _exportExcel() async {
    final excel = Excel.createExcel();
    final sheet = excel['Report'];
    sheet.appendRow([
      TextCellValue('Date'),
      TextCellValue('Hall'),
      TextCellValue('Slot'),
      TextCellValue('Customer'),
      TextCellValue('Phone'),
      TextCellValue('PAX'),
      TextCellValue('Amount'),
      TextCellValue('Menu'),
    ]);

    for (var b in filtered) {
      sheet.appendRow([
        TextCellValue(DateFormat('yyyy-MM-dd').format(b.date)),
        TextCellValue(b.hallSlots
            .map((hs) => '${hs['hallName']} - ${hs['slotLabel']}')
            .join(", ")),
        TextCellValue(
            b.hallSlots.map((hs) => hs['slotLabel'] ?? '').join(", ")),
        TextCellValue(b.customerName),
        TextCellValue(b.phone),
        TextCellValue(b.pax.toString()),
        TextCellValue(b.amount.toString()),
        TextCellValue(b.menu.replaceAll('\n', ' | ')), // formatted for Excel
      ]);
    }

    final bytes = excel.encode()!;
    final dir = await getExternalStorageDirectory();
    final file = File(
        '${dir!.path}/banquet_report_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.xlsx');
    await file.writeAsBytes(bytes);

    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('Exported to ${file.path}')));
  }

  Future<void> _pickDate(bool isFrom) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: isFrom ? (fromDate ?? now) : (toDate ?? now),
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 2),
    );
    if (picked != null) {
      setState(() {
        if (isFrom)
          fromDate = picked;
        else
          toDate = picked;
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
        title: Text('Banquet Reports'),
        actions: [
          if (filtered.isNotEmpty)
            IconButton(onPressed: _exportExcel, icon: Icon(Icons.download)),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(8),
            child: Row(
              children: [
                Expanded(
                    child: _dateFilterBtn(
                        'From', fromDate, () => _pickDate(true))),
                SizedBox(width: 10),
                Expanded(
                    child:
                        _dateFilterBtn('To', toDate, () => _pickDate(false))),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: [
                  DataColumn(label: Text('Date')),
                  DataColumn(label: Text('Hall')),
                  DataColumn(label: Text('Slot')),
                  DataColumn(label: Text('Customer')),
                  DataColumn(label: Text('Phone')),
                  DataColumn(label: Text('PAX')),
                  DataColumn(label: Text('Amount')),
                  DataColumn(label: Text('Menu')),
                ],
                rows: filtered.map((b) {
                  return DataRow(cells: [
                    DataCell(Text(DateFormat('yyyy-MM-dd').format(b.date))),
                    DataCell(Text(b.hallSlots
                        .map((hs) => '${hs['hallName']} - ${hs['slotLabel']}')
                        .join(", "))),
                    DataCell(Text(b.hallSlots
                        .map((hs) => hs['slotLabel'] ?? '')
                        .join(", "))),
                    DataCell(Text(b.customerName)),
                    DataCell(Text(b.phone)),
                    DataCell(Text(b.pax.toString())),
                    DataCell(Text(b.amount.toString())),
                    DataCell(Text(
                      b.menu.split('\n').map((line) => line.trim()).join('\n'),
                      maxLines: 10,
                      overflow: TextOverflow.ellipsis,
                    )),
                  ]);
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dateFilterBtn(String label, DateTime? date, VoidCallback onTap) {
    final text = date != null ? DateFormat('yyyy-MM-dd').format(date) : label;
    return ElevatedButton(onPressed: onTap, child: Text(text));
  }
}
