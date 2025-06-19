import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import '../../models/customer.dart';
import '../../models/banquet_booking.dart';

class CombinedReportsScreen extends StatefulWidget {
  @override
  State<CombinedReportsScreen> createState() => _CombinedReportsScreenState();
}

class _CombinedReportsScreenState extends State<CombinedReportsScreen> {
  DateTime? fromDate;
  DateTime? toDate;
  List<Customer> queueList = [];
  List<BanquetBooking> banquetList = [];

  void _loadData() {
    final queueBox = Hive.box<Customer>('completedQueue');
    final banquetBox = Hive.box<BanquetBooking>('banquetBookings');

    final allQueue = queueBox.values.toList();
    final allBanquet = banquetBox.values.toList();

    setState(() {
      queueList = allQueue.where((c) {
        final d = c.key as int? ?? 0;
        final date = DateTime.fromMillisecondsSinceEpoch(d);
        return _inDateRange(date);
      }).toList();

      banquetList = allBanquet.where((b) => _inDateRange(b.date)).toList();
    });
  }

  bool _inDateRange(DateTime d) {
    if (fromDate != null && d.isBefore(fromDate!)) return false;
    if (toDate != null && d.isAfter(toDate!)) return false;
    return true;
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
        if (isFrom) fromDate = picked;
        else toDate = picked;
      });
      _loadData();
    }
  }

  Future<void> _exportExcel() async {
    final excel = Excel.createExcel();
    final sheet = excel['CombinedReport'];

    sheet.appendRow([
      TextCellValue('Type'),
      TextCellValue('Date'),
      TextCellValue('Name'),
      TextCellValue('Phone'),
      TextCellValue('PAX'),
      TextCellValue('Amount'),
      TextCellValue('Details'),
    ]);

    for (var c in queueList) {
      sheet.appendRow([
        TextCellValue('Queue'),
        TextCellValue('-'),
        TextCellValue(c.name),
        TextCellValue(c.phone),
        TextCellValue(c.pax.toString()),
        TextCellValue('-'),
        TextCellValue('Token ${c.token}'),
      ]);
    }

    for (var b in banquetList) {
      sheet.appendRow([
        TextCellValue('Banquet'),
        TextCellValue(DateFormat('yyyy-MM-dd').format(b.date)),
        TextCellValue(b.customerName),
        TextCellValue(b.phone),
        TextCellValue(b.pax.toString()),
        TextCellValue(b.amount.toString()),
        TextCellValue('${b.hallName} - ${b.slotLabel}'),
      ]);
    }

    final bytes = excel.encode()!;
    final dir = await getExternalStorageDirectory();
    final file = File('${dir!.path}/combined_report_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.xlsx');
    await file.writeAsBytes(bytes);

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Exported to ${file.path}')));
  }

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Combined Reports'),
        actions: [
          IconButton(onPressed: _exportExcel, icon: Icon(Icons.download)),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(child: _dateBtn('From', fromDate, () => _pickDate(true))),
                SizedBox(width: 10),
                Expanded(child: _dateBtn('To', toDate, () => _pickDate(false))),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              children: [
                _sectionTitle('Queue Customers'),
                ...queueList.map((c) => ListTile(
                  title: Text(c.name),
                  subtitle: Text('Phone: ${c.phone} | PAX: ${c.pax} | Token: ${c.token}'),
                )),
                _sectionTitle('Banquet Bookings'),
                ...banquetList.map((b) => ListTile(
                  title: Text(b.customerName),
                  subtitle: Text('${b.hallName} - ${b.slotLabel} | ${b.pax} PAX | ₹${b.amount}'),
                )),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, left: 16, bottom: 8),
      child: Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
    );
  }

  Widget _dateBtn(String label, DateTime? date, VoidCallback onTap) {
    final text = date != null ? DateFormat('yyyy-MM-dd').format(date) : label;
    return ElevatedButton(onPressed: onTap, child: Text(text));
  }
}