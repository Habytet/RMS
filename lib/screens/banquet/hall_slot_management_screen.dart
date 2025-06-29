import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/banquet_provider.dart';
import '../../models/hall.dart';
import '../../models/slot.dart';
import '../../providers/user_provider.dart';

class HallSlotManagementScreen extends StatefulWidget {
  @override
  State<HallSlotManagementScreen> createState() =>
      _HallSlotManagementScreenState();
}

class _HallSlotManagementScreenState extends State<HallSlotManagementScreen> {
  final _hallController = TextEditingController();
  String? _selectedBranchId;
  final Map<String, TextEditingController> _slotControllers = {};

  @override
  void dispose() {
    _hallController.dispose();
    for (final c in _slotControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _addHall(BanquetProvider provider) async {
    final name = _hallController.text.trim();
    if (name.isNotEmpty) {
      await provider.addHall(name);
      _hallController.clear();
    }
  }

  void _addSlot(BanquetProvider provider, String hallName) async {
    final controller = _slotControllers[hallName]!;
    final slot = controller.text.trim();
    if (slot.isNotEmpty) {
      await provider.addSlot(hallName, slot);
      controller.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = context.watch<UserProvider>();
    final isCorporate = userProvider.currentUser?.branchId == 'all';
    final branches = userProvider.branches;

    // Set default branch for admin only once
    if (isCorporate && _selectedBranchId == null && branches.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _selectedBranchId = branches
                .firstWhere((b) => b.id != 'all', orElse: () => branches.first)
                .id;
          });
        }
      });
    } else if (!isCorporate && _selectedBranchId == null) {
      _selectedBranchId = userProvider.currentBranchId;
    }

    if (_selectedBranchId == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return ChangeNotifierProvider<BanquetProvider>(
      key: ValueKey(_selectedBranchId),
      create: (_) => BanquetProvider(branchId: _selectedBranchId!),
      child: Consumer<BanquetProvider>(
        builder: (context, provider, _) {
          final halls = provider.halls;
          // Ensure a controller exists for each hall
          for (final hall in halls) {
            _slotControllers.putIfAbsent(
                hall.name, () => TextEditingController());
          }
          // Remove controllers for deleted halls
          _slotControllers.removeWhere(
              (hallName, _) => !halls.any((h) => h.name == hallName));

          return Scaffold(
            appBar: AppBar(title: Text('Hall & Slot Management')),
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: ListView(
                children: [
                  if (isCorporate)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16.0),
                      child: DropdownButtonFormField<String>(
                        value: _selectedBranchId,
                        decoration: const InputDecoration(
                            labelText: 'Select Branch',
                            border: OutlineInputBorder()),
                        items: [
                          ...branches.where((b) => b.id != 'all').map((b) =>
                              DropdownMenuItem(
                                  value: b.id, child: Text(b.name))),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _selectedBranchId = value;
                          });
                        },
                      ),
                    ),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _hallController,
                          decoration:
                              InputDecoration(labelText: 'New Hall Name'),
                        ),
                      ),
                      SizedBox(width: 10),
                      ElevatedButton(
                        onPressed: () => _addHall(provider),
                        child: Text('Add Hall'),
                      ),
                    ],
                  ),
                  SizedBox(height: 20),
                  ...halls.map((hall) {
                    final hallSlots = provider.getSlotsForHall(hall.name);
                    final slotController = _slotControllers[hall.name]!;
                    return Card(
                      child: ExpansionTile(
                        title: Text(hall.name),
                        trailing: IconButton(
                          icon: Icon(Icons.delete, color: Colors.red),
                          onPressed: () async {
                            await provider.removeHall(hall.name);
                          },
                        ),
                        children: [
                          ...hallSlots.map((s) => ListTile(
                                title: Text(s.label),
                                trailing: IconButton(
                                  icon: Icon(Icons.delete),
                                  onPressed: () async {
                                    await provider.removeSlot(
                                        s.hallName, s.label);
                                  },
                                ),
                              )),
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: slotController,
                                    decoration: InputDecoration(
                                        labelText: 'New Slot Label'),
                                  ),
                                ),
                                SizedBox(width: 10),
                                ElevatedButton(
                                  onPressed: () =>
                                      _addSlot(provider, hall.name),
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
        },
      ),
    );
  }
}
