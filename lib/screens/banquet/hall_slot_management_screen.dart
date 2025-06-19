import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/banquet_provider.dart';
import '../../models/hall.dart';
import '../../models/slot.dart';

class HallSlotManagementScreen extends StatelessWidget {
  final _hallController = TextEditingController();
  final _slotController = TextEditingController();

  void _addHall(BuildContext context) {
    final name = _hallController.text.trim();
    if (name.isNotEmpty) {
      context.read<BanquetProvider>().addHall(name);
      _hallController.clear();
    }
  }

  void _addSlot(BuildContext context, String hallName) {
    final slot = _slotController.text.trim();
    if (slot.isNotEmpty) {
      context.read<BanquetProvider>().addSlot(hallName, slot);
      _slotController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<BanquetProvider>();
    final halls = provider.halls;

    return Scaffold(
      appBar: AppBar(title: Text('Hall & Slot Management')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _hallController,
                    decoration: InputDecoration(labelText: 'New Hall Name'),
                  ),
                ),
                SizedBox(width: 10),
                ElevatedButton(
                  onPressed: () => _addHall(context),
                  child: Text('Add Hall'),
                ),
              ],
            ),
            SizedBox(height: 20),
            ...halls.map((hall) {
              final hallSlots = provider.getSlotsForHall(hall.name);
              return Card(
                child: ExpansionTile(
                  title: Text(hall.name),
                  trailing: IconButton(
                    icon: Icon(Icons.delete, color: Colors.red),
                    onPressed: () => provider.removeHall(hall.name),
                  ),
                  children: [
                    ...hallSlots.map((s) => ListTile(
                      title: Text(s.label),
                      trailing: IconButton(
                        icon: Icon(Icons.delete),
                        onPressed: () =>
                            provider.removeSlot(s.hallName, s.label),
                      ),
                    )),
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _slotController,
                              decoration:
                              InputDecoration(labelText: 'New Slot Label'),
                            ),
                          ),
                          SizedBox(width: 10),
                          ElevatedButton(
                            onPressed: () => _addSlot(context, hall.name),
                            child: Text('Add Slot'),
                          ),
                        ],
                      ),
                    )
                  ],
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }
}