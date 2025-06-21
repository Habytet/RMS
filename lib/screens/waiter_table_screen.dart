// lib/screens/waiter_table_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/token_provider.dart';

class WaiterTableScreen extends StatefulWidget {
  const WaiterTableScreen({super.key});

  @override
  State<WaiterTableScreen> createState() => _WaiterTableScreenState();
}

class _WaiterTableScreenState extends State<WaiterTableScreen> {
  final _tableController = TextEditingController();
  Timer? _timer; // To refresh the waiting time display

  @override
  void initState() {
    super.initState();
    // This timer will refresh the UI every minute to update waiting times.
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _tableController.dispose();
    _timer?.cancel(); // Make sure to cancel the timer to prevent memory leaks.
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // We watch the provider so the UI rebuilds when the queue or tables change.
    final provider = context.watch<TokenProvider>();
    final tables = provider.availableTables;
    final queue = provider.queue;

    return Scaffold(
      appBar: AppBar(title: const Text('Waiter Station')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- This is the existing UI for managing tables ---
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _tableController,
                    decoration: const InputDecoration(
                      labelText: 'Enter Table No.',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: () {
                    final text = _tableController.text.trim();
                    final tableNum = int.tryParse(text);
                    if (tableNum != null) {
                      provider.addTable(tableNum);
                      _tableController.clear();
                    }
                  },
                  child: const Text('Submit'),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Text('Available Tables:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: tables.map((table) {
                return Chip(
                  label: Text('Table $table'),
                  onDeleted: () => provider.removeTable(table),
                );
              }).toList(),
            ),
            const Divider(height: 32),

            // --- NEW: This is the read-only view of the customer queue ---
            const Text('Customers Waiting:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            Expanded(
              child: queue.isEmpty
                  ? const Center(child: Text('No customers are currently waiting.'))
                  : ListView.builder(
                itemCount: queue.length,
                itemBuilder: (context, index) {
                  final c = queue[index];
                  final duration = DateTime.now().difference(c.registeredAt);
                  final isLate = duration.inMinutes >= 15;

                  // This is the read-only card for the waiter.
                  // It has no buttons and cannot be swiped.
                  return Card(
                    shape: RoundedRectangleBorder(
                      side: BorderSide(
                        color: c.isCalled ? Colors.green : Colors.transparent,
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    color: isLate ? Colors.red.shade400 : null,
                    child: ListTile(
                      title: Text(
                        '${c.name} (${c.pax} adults, ${c.children} kids)',
                        style: TextStyle(color: isLate ? Colors.white : null, fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        'Token: ${c.token} | Waiting: ${duration.inMinutes} mins',
                        style: TextStyle(color: isLate ? Colors.white70 : null),
                      ),
                      // No trailing buttons for the waiter.
                    ),
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
