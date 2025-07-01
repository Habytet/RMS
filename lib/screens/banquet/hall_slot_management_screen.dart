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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Hall "$name" added successfully'),
          backgroundColor: Colors.green.shade600,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _addSlot(BanquetProvider provider, String hallName) async {
    final controller = _slotControllers[hallName]!;
    final slot = controller.text.trim();
    if (slot.isNotEmpty) {
      await provider.addSlot(hallName, slot);
      controller.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Slot "$slot" added to "$hallName"'),
          backgroundColor: Colors.green.shade600,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _removeHall(BanquetProvider provider, String hallName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Remove Hall'),
        content: Text(
            'Are you sure you want to remove "$hallName"? This will also remove all associated slots.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
            ),
            child: Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await provider.removeHall(hallName);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Hall "$hallName" removed successfully'),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _removeSlot(
      BanquetProvider provider, String hallName, String slotLabel) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Remove Slot'),
        content: Text(
            'Are you sure you want to remove "$slotLabel" from "$hallName"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
            ),
            child: Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await provider.removeSlot(hallName, slotLabel);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Slot "$slotLabel" removed successfully'),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
        ),
      );
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
      return Scaffold(
        appBar: AppBar(
          title: Text('Banquet Setup'),
          backgroundColor: Colors.red.shade300,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.red.shade50,
                Colors.white,
              ],
            ),
          ),
          child: Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.red.shade400),
            ),
          ),
        ),
      );
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

          // Calculate statistics
          final totalSlots = halls.fold<int>(0,
              (sum, hall) => sum + provider.getSlotsForHall(hall.name).length);

          return Scaffold(
            appBar: AppBar(
              title: Text('Banquet Setup'),
              backgroundColor: Colors.red.shade300,
              foregroundColor: Colors.white,
              elevation: 0,
            ),
            body: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.red.shade50,
                    Colors.white,
                  ],
                ),
              ),
              child: Column(
                children: [
                  // Branch Selection (for corporate users)
                  if (isCorporate)
                    Container(
                      margin: EdgeInsets.all(16),
                      padding: EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 10,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.business, color: Colors.red.shade600),
                              SizedBox(width: 8),
                              Text(
                                'Select Branch',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red.shade700,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 16),
                          DropdownButtonFormField<String>(
                            value: _selectedBranchId,
                            decoration: InputDecoration(
                              labelText: 'Branch',
                              hintText: 'Choose a branch...',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                    color: Colors.red.shade400, width: 2),
                              ),
                              prefixIcon: Icon(Icons.location_on,
                                  color: Colors.red.shade400),
                            ),
                            items: branches
                                .where((b) => b.id != 'all')
                                .map((b) => DropdownMenuItem(
                                      value: b.id,
                                      child: Text(b.name),
                                    ))
                                .toList(),
                            onChanged: (value) {
                              setState(() {
                                _selectedBranchId = value;
                              });
                            },
                          ),
                        ],
                      ),
                    ),

                  // Statistics Overview
                  Container(
                    margin: EdgeInsets.all(16),
                    padding: EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: _buildStatCard(
                            'Total Halls',
                            halls.length.toString(),
                            Icons.meeting_room,
                            Colors.blue.shade100,
                            Colors.blue.shade600,
                          ),
                        ),
                        SizedBox(width: 16),
                        Expanded(
                          child: _buildStatCard(
                            'Total Slots',
                            totalSlots.toString(),
                            Icons.schedule,
                            Colors.green.shade100,
                            Colors.green.shade600,
                          ),
                        ),
                        SizedBox(width: 16),
                        Expanded(
                          child: _buildStatCard(
                            'Avg Slots/Hall',
                            halls.isEmpty
                                ? '0'
                                : (totalSlots / halls.length)
                                    .toStringAsFixed(1),
                            Icons.analytics,
                            Colors.orange.shade100,
                            Colors.orange.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Add Hall Section
                  Container(
                    margin: EdgeInsets.symmetric(horizontal: 16),
                    padding: EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.add_business,
                                color: Colors.red.shade600),
                            SizedBox(width: 8),
                            Text(
                              'Add New Hall',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.red.shade700,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _hallController,
                                decoration: InputDecoration(
                                  labelText: 'Hall Name',
                                  hintText: 'Enter hall name...',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                        color: Colors.red.shade400, width: 2),
                                  ),
                                  prefixIcon: Icon(Icons.meeting_room,
                                      color: Colors.red.shade400),
                                ),
                                onSubmitted: (_) => _addHall(provider),
                              ),
                            ),
                            SizedBox(width: 12),
                            ElevatedButton.icon(
                              onPressed: () => _addHall(provider),
                              icon: Icon(Icons.add, size: 20),
                              label: Text('Add Hall'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red.shade400,
                                foregroundColor: Colors.white,
                                padding: EdgeInsets.symmetric(
                                    horizontal: 20, vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 16),

                  // Halls List
                  Expanded(
                    child: halls.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.meeting_room_outlined,
                                  size: 64,
                                  color: Colors.grey.shade400,
                                ),
                                SizedBox(height: 16),
                                Text(
                                  'No halls configured',
                                  style: TextStyle(
                                    fontSize: 18,
                                    color: Colors.grey.shade600,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'Add your first hall to get started',
                                  style: TextStyle(
                                    color: Colors.grey.shade500,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: EdgeInsets.symmetric(horizontal: 16),
                            itemCount: halls.length,
                            itemBuilder: (context, index) {
                              final hall = halls[index];
                              final hallSlots =
                                  provider.getSlotsForHall(hall.name);
                              final slotController =
                                  _slotControllers[hall.name]!;

                              return Container(
                                margin: EdgeInsets.only(bottom: 16),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.1),
                                      blurRadius: 10,
                                      offset: Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: ExpansionTile(
                                  leading: CircleAvatar(
                                    backgroundColor: Colors.red.shade100,
                                    child: Icon(
                                      Icons.meeting_room,
                                      color: Colors.red.shade600,
                                    ),
                                  ),
                                  title: Text(
                                    hall.name,
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.red.shade700,
                                    ),
                                  ),
                                  subtitle: Text(
                                    '${hallSlots.length} slot${hallSlots.length == 1 ? '' : 's'}',
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: Icon(Icons.delete,
                                            color: Colors.red.shade400),
                                        onPressed: () =>
                                            _removeHall(provider, hall.name),
                                        tooltip: 'Remove Hall',
                                      ),
                                      Icon(Icons.expand_more,
                                          color: Colors.grey.shade600),
                                    ],
                                  ),
                                  children: [
                                    // Slots List
                                    if (hallSlots.isNotEmpty)
                                      Container(
                                        margin: EdgeInsets.symmetric(
                                            horizontal: 16),
                                        child: Column(
                                          children: hallSlots
                                              .map((slot) => Container(
                                                    margin: EdgeInsets.only(
                                                        bottom: 8),
                                                    padding: EdgeInsets.all(12),
                                                    decoration: BoxDecoration(
                                                      color:
                                                          Colors.grey.shade50,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              8),
                                                      border: Border.all(
                                                          color: Colors
                                                              .grey.shade200),
                                                    ),
                                                    child: Row(
                                                      children: [
                                                        Icon(
                                                          Icons.schedule,
                                                          color: Colors
                                                              .green.shade600,
                                                          size: 20,
                                                        ),
                                                        SizedBox(width: 12),
                                                        Expanded(
                                                          child: Text(
                                                            slot.label,
                                                            style: TextStyle(
                                                              fontSize: 16,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w500,
                                                            ),
                                                          ),
                                                        ),
                                                        IconButton(
                                                          icon: Icon(
                                                              Icons.delete,
                                                              color: Colors.red
                                                                  .shade400),
                                                          onPressed: () =>
                                                              _removeSlot(
                                                                  provider,
                                                                  hall.name,
                                                                  slot.label),
                                                          tooltip:
                                                              'Remove Slot',
                                                        ),
                                                      ],
                                                    ),
                                                  ))
                                              .toList(),
                                        ),
                                      ),

                                    // Add Slot Section
                                    Container(
                                      margin: EdgeInsets.all(16),
                                      padding: EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: Colors.green.shade50,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                            color: Colors.green.shade200),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Icon(Icons.add_circle,
                                                  color: Colors.green.shade600),
                                              SizedBox(width: 8),
                                              Text(
                                                'Add New Slot',
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.green.shade700,
                                                ),
                                              ),
                                            ],
                                          ),
                                          SizedBox(height: 12),
                                          Row(
                                            children: [
                                              Expanded(
                                                child: TextField(
                                                  controller: slotController,
                                                  decoration: InputDecoration(
                                                    labelText: 'Slot Label',
                                                    hintText:
                                                        'e.g., Morning, Afternoon, Evening',
                                                    border: OutlineInputBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              8),
                                                    ),
                                                    focusedBorder:
                                                        OutlineInputBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              8),
                                                      borderSide: BorderSide(
                                                          color: Colors
                                                              .green.shade400,
                                                          width: 2),
                                                    ),
                                                    prefixIcon: Icon(
                                                        Icons.schedule,
                                                        color: Colors
                                                            .green.shade400),
                                                  ),
                                                  onSubmitted: (_) => _addSlot(
                                                      provider, hall.name),
                                                ),
                                              ),
                                              SizedBox(width: 12),
                                              ElevatedButton.icon(
                                                onPressed: () => _addSlot(
                                                    provider, hall.name),
                                                icon: Icon(Icons.add, size: 18),
                                                label: Text('Add'),
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor:
                                                      Colors.green.shade600,
                                                  foregroundColor: Colors.white,
                                                  padding: EdgeInsets.symmetric(
                                                      horizontal: 16,
                                                      vertical: 12),
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            8),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon,
      Color bgColor, Color iconColor) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: iconColor, size: 32),
          SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: iconColor,
            ),
          ),
          SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
