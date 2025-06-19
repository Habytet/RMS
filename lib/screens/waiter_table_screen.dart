import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/token_provider.dart';

class WaiterTableScreen extends StatefulWidget {
  @override
  State<WaiterTableScreen> createState() => _WaiterTableScreenState();
}

class _WaiterTableScreenState extends State<WaiterTableScreen> {
  final _tableController = TextEditingController();

  @override
  void dispose() {
    _tableController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TokenProvider>();
    final tables = provider.availableTables;

    return Scaffold(
      appBar: AppBar(title: const Text('Manage Available Tables')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
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
            const Text(
              'Available Tables:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              children: tables.map((table) {
                return Chip(
                  label: Text('Table $table'),
                  deleteIcon: const Icon(Icons.close),
                  onDeleted: () => provider.removeTable(table),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}