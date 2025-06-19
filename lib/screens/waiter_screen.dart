import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/token_provider.dart';

class WaiterScreen extends StatefulWidget {
  @override
  State<WaiterScreen> createState() => _WaiterScreenState();
}

class _WaiterScreenState extends State<WaiterScreen> {
  final _tableController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TokenProvider>();
    final tables = provider.availableTables;

    return Scaffold(
      appBar: AppBar(title: Text('Available Tables')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text('Enter available table number to add below:'),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _tableController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(labelText: 'Table Number'),
                  ),
                ),
                SizedBox(width: 10),
                ElevatedButton(
                  onPressed: () {
                    final table = int.tryParse(_tableController.text.trim());
                    if (table != null) {
                      provider.addTable(table);
                      _tableController.clear();
                    }
                  },
                  child: Text('Submit'),
                ),
              ],
            ),
            SizedBox(height: 20),
            Divider(),
            Text('Available Tables:', style: TextStyle(fontWeight: FontWeight.bold)),
            Wrap(
              spacing: 8,
              children: tables.map((t) => Chip(
                label: Text('$t'),
                onDeleted: () => provider.removeTable(t),
              )).toList(),
            ),
          ],
        ),
      ),
    );
  }
}