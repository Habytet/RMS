import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../providers/token_provider.dart';

class QueueReportsScreen extends StatefulWidget {
  @override
  State<QueueReportsScreen> createState() => _QueueReportsScreenState();
}

class _QueueReportsScreenState extends State<QueueReportsScreen> {
  DateTimeRange? _range;
  final DateFormat _fmt = DateFormat('yyyy-MM-dd');
  final DateFormat _timeFmt = DateFormat('kk:mm');
  List data = [];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _range = DateTimeRange(start: now.subtract(Duration(days: 7)), end: now);
    _loadData();
  }

  Future<void> _pickRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _range = picked;
        _loadData();
      });
    }
  }

  void _loadData() {
    final list = context.read<TokenProvider>().allHistory;
    if (_range == null) {
      setState(() => data = []);
      return;
    }

    final filtered = list.where((h) {
      final d = h.registeredAt;
      return d.isAfter(_range!.start.subtract(Duration(days: 1))) &&
          d.isBefore(_range!.end.add(Duration(days: 1)));
    }).toList();

    setState(() => data = filtered);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Queue Reports')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                ElevatedButton(
                  onPressed: _pickRange,
                  child: Text(
                    _range == null
                        ? 'Pick Date Range'
                        : '${_fmt.format(_range!.start)} → ${_fmt.format(_range!.end)}',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (data.isEmpty)
              Text('No data for selected range.')
            else
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columns: const [
                      DataColumn(label: Text('S.No.')),
                      DataColumn(label: Text('Name')),
                      DataColumn(label: Text('Phone')),
                      DataColumn(label: Text('PAX')),
                      DataColumn(label: Text('Token')),
                      DataColumn(label: Text('Registered At')),
                      DataColumn(label: Text('Called At')),
                      DataColumn(label: Text('Wait (mins)')),
                      DataColumn(label: Text('Date')),
                      DataColumn(label: Text('Operator')),
                    ],
                    rows: List.generate(data.length, (i) {
                      final h = data[i];
                      final wait = h.calledAt != null
                          ? h.calledAt!.difference(h.registeredAt).inMinutes
                          : '-';
                      return DataRow(cells: [
                        DataCell(Text('${i + 1}')),
                        DataCell(Text(h.name)),
                        DataCell(Text(h.phone)),
                        DataCell(Text('${h.pax}')),
                        DataCell(Text('${h.token}')),
                        DataCell(Text(_timeFmt.format(h.registeredAt))),
                        DataCell(Text(h.calledAt != null
                            ? _timeFmt.format(h.calledAt!)
                            : '')),
                        DataCell(Text('$wait')),
                        DataCell(Text(_fmt.format(h.registeredAt))),
                        DataCell(Text(h.operator ?? '')),
                      ]);
                    }),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}