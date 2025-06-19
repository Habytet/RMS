import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import '../models/customer.dart';
import '../providers/token_provider.dart';

class CustomerCallingTab extends StatefulWidget {
  @override
  State<CustomerCallingTab> createState() => _CustomerCallingTabState();
}

class _CustomerCallingTabState extends State<CustomerCallingTab> {
  late Timer _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(Duration(minutes: 1), (_) {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TokenProvider>();
    final queue = provider.queue;
    final tables = provider.availableTables;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (tables.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text('Available Tables:', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: tables.map((table) {
                return Container(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  margin: EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.green),
                    borderRadius: BorderRadius.circular(8),
                    color: Colors.green.shade100,
                  ),
                  child: Text('Table $table', style: TextStyle(fontWeight: FontWeight.bold)),
                );
              }).toList(),
            ),
          ),
        ],
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text('Customers Waiting:', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
        Expanded(
          child: queue.isEmpty
              ? Center(child: Text('No customers in queue'))
              : ListView.builder(
            itemCount: queue.length,
            itemBuilder: (context, index) {
              final c = queue[index];
              final minutes = DateTime.now().difference(c.registeredAt).inMinutes;
              final isLate = minutes >= 15;

              return Card(
                color: isLate ? Colors.red : null,
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  title: Text('${c.name} (${c.pax} PAX)',
                      style: TextStyle(color: isLate ? Colors.white : null)),
                  subtitle: Text(
                    'Phone: ${c.phone} — Token: ${c.token}\nWaiting: ${minutes} min',
                    style: TextStyle(color: isLate ? Colors.white70 : null),
                  ),
                  trailing: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isLate ? Colors.white : Colors.blue,
                      foregroundColor: isLate ? Colors.red : Colors.white,
                    ),
                    onPressed: () => provider.callNext(c.token),
                    child: Text('Call'),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}