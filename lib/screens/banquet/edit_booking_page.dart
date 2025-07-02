import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:token_manager/screens/notification_screen/notification_bloc.dart';
import 'package:token_manager/screens/notification_screen/notification_event.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/banquet_booking.dart';
import '../../models/menu.dart';
import '../../providers/banquet_provider.dart';
import 'select_menu_items_page.dart';
import 'banquet_calendar_screen.dart';
import '../../providers/user_provider.dart';

class EditBookingPage extends StatefulWidget {
  final BanquetBooking booking;
  final String docId;
  final String branchId;
  final NotificationBloc? notificationBloc;

  const EditBookingPage(
      {required this.booking,
      required this.docId,
      required this.branchId,
      this.notificationBloc});

  @override
  State<EditBookingPage> createState() => _EditBookingPageState();
}

class _EditBookingPageState extends State<EditBookingPage>
    with WidgetsBindingObserver {
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _callbackController;
  late TextEditingController _paxController;
  late TextEditingController _advanceController;
  late TextEditingController _commentsController;
  late TextEditingController _totalAmountController;
  late double _totalAmount;
  late double _remainingAmount;
  DateTime? _callbackTime;
  bool justMadeCall = false;

  Menu? _selectedMenu;
  Map<String, Set<String>> _selectedItems = {};

  // List to store selected hall+slot combinations
  List<Map<String, String>> _selectedHallSlots = [];

  bool _isSaving = false;
  bool _isConfirming = false;
  bool _slotsAvailable =
      true; // Track if slots are still available for confirmation

  Future<List<Menu>> _fetchMenus() async {
    // Use branch-level menus instead of hall-level
    final snapshot = await FirebaseFirestore.instance
        .collection('branches')
        .doc(widget.branchId)
        .collection('menus')
        .get();
    return snapshot.docs.map((doc) => Menu.fromMap(doc.data())).toList();
  }

  Future<Tuple2<Menu?, Map<String, Set<String>>>> _parseMenu(String raw) async {
    final menus = await _fetchMenus();
    final menuName = raw.split('\n').first;
    final menu = menus.firstWhere((m) => m.name == menuName,
        orElse: () => Menu(name: '', price: 0));

    final selections = <String, Set<String>>{};
    raw.split('\n').skip(1).forEach((line) {
      final parts = line.split(':');
      if (parts.length == 2) {
        final category = parts[0].trim();
        final items = parts[1].split(',').map((s) => s.trim()).toSet();
        selections[category] = items;
      }
    });
    return Tuple2(menu.name.isNotEmpty ? menu : null, selections);
  }

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.booking.customerName);
    _phoneController = TextEditingController(text: widget.booking.phone);
    _callbackController =
        TextEditingController(text: widget.booking.callbackComment ?? '');
    _paxController = TextEditingController(text: widget.booking.pax.toString());
    _advanceController =
        TextEditingController(text: widget.booking.amount.toString());
    _commentsController = TextEditingController(text: widget.booking.comments);
    _totalAmount = widget.booking.totalAmount;
    _remainingAmount = widget.booking.remainingAmount;
    _totalAmountController =
        TextEditingController(text: _totalAmount.toStringAsFixed(2));
    _callbackTime = widget.booking.callbackTime;

    // Initialize selected hall slots from the booking
    _selectedHallSlots = List.from(widget.booking.hallSlots);

    _parseMenu(widget.booking.menu).then((parsed) {
      setState(() {
        _selectedMenu = parsed.item1;
        _selectedItems = parsed.item2;
      });
    });

    // Check slot availability on init
    _checkAndUpdateSlotAvailability();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _callbackController.dispose();
    _paxController.dispose();
    _advanceController.dispose();
    _commentsController.dispose();
    _totalAmountController.dispose();
    super.dispose();
  }

  void _updateRemaining() {
    final received = double.tryParse(_advanceController.text.trim()) ?? 0.0;
    setState(() {
      _remainingAmount = _totalAmount - received;
    });
  }

  Future<void> _saveChanges() async {
    if (_isSaving) return; // Prevent multiple saves
    setState(() {
      _isSaving = true;
    });
    try {
      print('DEBUG: Starting to save booking changes');
      print('DEBUG: Document ID: ${widget.docId}');
      print('DEBUG: Branch ID (widget): ${widget.branchId}');
      print(
          'DEBUG: Firestore path: branches/${widget.branchId}/banquetBookings/${widget.docId}');
      print('DEBUG: Customer Name: ${_nameController.text.trim()}');

      final updated = widget.booking
        ..customerName = _nameController.text.trim()
        ..phone = _phoneController.text.trim()
        ..callbackComment = _callbackController.text.trim()
        ..pax = int.tryParse(_paxController.text.trim()) ?? widget.booking.pax
        ..amount = double.tryParse(_advanceController.text.trim()) ??
            widget.booking.amount
        ..totalAmount = _totalAmount
        ..remainingAmount = _remainingAmount
        ..comments = _commentsController.text.trim()
        ..callbackTime = _callbackTime
        ..hallSlots = _selectedHallSlots
        ..menu = _selectedMenu?.name != null
            ? _selectedMenu!.name +
                _selectedItems.entries
                    .map((e) => '\n${e.key}: ${e.value.join(", ")}')
                    .join()
            : widget.booking.menu;

      print('DEBUG: Updated booking data prepared');
      print('DEBUG: Directly updating Firestore with correct path');

      // Always directly update Firestore with the correct branchId to avoid provider issues
      await FirebaseFirestore.instance
          .collection('branches')
          .doc(widget.branchId)
          .collection('banquetBookings')
          .doc(widget.docId)
          .update(updated.toMap());

      print('DEBUG: Direct Firestore update successful');

      print('DEBUG: Booking updated successfully in Firestore');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Booking updated successfully!'),
          backgroundColor: Colors.green.shade600,
          duration: Duration(seconds: 2),
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      print('ERROR: Failed to update booking: $e');
      print('ERROR: Document ID was: ${widget.docId}');
      print('ERROR: Branch ID (widget) was: ${widget.branchId}');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update booking: ${e.toString()}'),
          backgroundColor: Colors.red.shade600,
          duration: Duration(seconds: 3),
        ),
      );
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  Future<void> _confirmBooking() async {
    if (_isConfirming) return; // Prevent multiple confirmations

    // Check if slots are still available before allowing confirmation
    final shouldConfirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Confirm Booking'),
          content: Text(
              'Are you sure you want to confirm this draft booking? This will move it to upcoming bookings and it cannot be undone.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade600,
                foregroundColor: Colors.white,
              ),
              child: Text('Confirm'),
            ),
          ],
        );
      },
    );

    if (shouldConfirm != true) return;

    setState(() {
      _isConfirming = true;
    });

    try {
      print('DEBUG: Starting to confirm booking');
      print('DEBUG: Document ID: ${widget.docId}');
      print('DEBUG: Branch ID (widget): ${widget.branchId}');

      // First save any changes
      final updated = widget.booking
        ..customerName = _nameController.text.trim()
        ..phone = _phoneController.text.trim()
        ..callbackComment = _callbackController.text.trim()
        ..pax = int.tryParse(_paxController.text.trim()) ?? widget.booking.pax
        ..amount = double.tryParse(_advanceController.text.trim()) ??
            widget.booking.amount
        ..totalAmount = _totalAmount
        ..remainingAmount = _remainingAmount
        ..comments = _commentsController.text.trim()
        ..callbackTime = _callbackTime
        ..hallSlots = _selectedHallSlots
        ..isDraft = false // Convert to confirmed booking
        ..menu = _selectedMenu?.name != null
            ? _selectedMenu!.name +
                _selectedItems.entries
                    .map((e) => '\n${e.key}: ${e.value.join(", ")}')
                    .join()
            : widget.booking.menu;

      print('DEBUG: Updated booking data prepared for confirmation');
      print('DEBUG: Directly updating Firestore with confirmed booking');

      // Update the booking in Firestore
      await FirebaseFirestore.instance
          .collection('branches')
          .doc(widget.branchId)
          .collection('banquetBookings')
          .doc(widget.docId)
          .update(updated.toMap());

      print('DEBUG: Booking confirmed successfully in Firestore');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Booking confirmed successfully!'),
          backgroundColor: Colors.green.shade600,
          duration: Duration(seconds: 2),
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      print('ERROR: Failed to confirm booking: $e');
      print('ERROR: Document ID was: ${widget.docId}');
      print('ERROR: Branch ID (widget) was: ${widget.branchId}');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to confirm booking: ${e.toString()}'),
          backgroundColor: Colors.red.shade600,
          duration: Duration(seconds: 3),
        ),
      );
    } finally {
      setState(() {
        _isConfirming = false;
      });
    }
  }

  /// Check if the current booking's slots are still available (excluding the current booking itself)
  Future<List<Map<String, String>>> _checkSlotAvailability() async {
    try {
      // Get all confirmed bookings for the same date
      final confirmedBookings = await FirebaseFirestore.instance
          .collection('branches')
          .doc(widget.branchId)
          .collection('banquetBookings')
          .where('date', isEqualTo: Timestamp.fromDate(widget.booking.date))
          .where('isDraft', isEqualTo: false)
          .get();

      List<Map<String, String>> unavailableSlots = [];

      // Check each of our selected hall-slots against confirmed bookings
      for (var selectedSlot in _selectedHallSlots) {
        final hallName = selectedSlot['hallName'] ?? '';
        final slotLabel = selectedSlot['slotLabel'] ?? '';

        // Check if any confirmed booking (other than this one) uses this slot
        bool isSlotTaken = confirmedBookings.docs.any((doc) {
          // Skip our own booking
          if (doc.id == widget.docId) return false;

          final bookingData = doc.data();
          final booking = BanquetBooking.fromMap(bookingData);

          // Check if this booking contains our hall-slot combination
          return booking.containsHallSlot(hallName, slotLabel);
        });

        if (isSlotTaken) {
          unavailableSlots.add({
            'hallName': hallName,
            'slotLabel': slotLabel,
          });
        }
      }

      return unavailableSlots;
    } catch (e) {
      print('ERROR: Failed to check slot availability: $e');
      return [];
    }
  }

  /// Check slot availability and update UI state
  Future<void> _checkAndUpdateSlotAvailability() async {
    if (!widget.booking.isDraft) return; // Only check for draft bookings

    final unavailableSlots = await _checkSlotAvailability();
    setState(() {
      _slotsAvailable = unavailableSlots.isEmpty;
    });
  }

  void _showAddHallSlotDialog(BuildContext context, BanquetProvider provider) {
    print('DEBUG: _showAddHallSlotDialog called');
    print('DEBUG: Selected hall slots: $_selectedHallSlots');
    print('DEBUG: Provider branchId: ${provider.branchId}');
    print('DEBUG: Widget branchId: ${widget.branchId}');
    print('DEBUG: Provider halls: ${provider.halls.length}');
    print('DEBUG: Provider slots: ${provider.slots.length}');

    // Check if provider has loaded data
    if (provider.halls.isEmpty || provider.slots.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Loading halls and slots data... Please try again in a moment.'),
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    final availableHallSlots = provider.getAvailableHallSlotsExcluding(
        widget.booking.date, _selectedHallSlots);

    print(
        'DEBUG: Available hall slots (excluding selected): ${availableHallSlots.length}');

    if (availableHallSlots.isEmpty) {
      final allAvailable = provider.getAvailableHallSlots(widget.booking.date);
      print('DEBUG: All available hall slots: ${allAvailable.length}');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'No additional hall+slot combinations available for this date. '
              'Total available: ${allAvailable.length}, Already selected: ${_selectedHallSlots.length}'),
          duration: Duration(seconds: 5),
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 12,
            left: 16,
            right: 16,
            top: 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              SizedBox(height: 16),
              Text(
                'Select Additional Hall & Slot',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.red.shade600,
                ),
              ),
              SizedBox(height: 16),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: availableHallSlots.length,
                  itemBuilder: (context, index) {
                    final hallSlot = availableHallSlots[index];
                    final hasDraft = provider.hasDraftBookings(
                        widget.booking.date,
                        hallSlot['hallName'] ?? '',
                        hallSlot['slotLabel'] ?? '');

                    return Card(
                      margin: EdgeInsets.only(bottom: 8),
                      elevation: 1,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        contentPadding: EdgeInsets.all(16),
                        title: Text(
                          '${hallSlot['hallName']} - ${hallSlot['slotLabel']}',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                        subtitle: hasDraft
                            ? Padding(
                                padding: EdgeInsets.only(top: 4),
                                child: Text(
                                  'Has draft booking',
                                  style: TextStyle(
                                    color: Colors.orange.shade600,
                                    fontSize: 12,
                                  ),
                                ),
                              )
                            : null,
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (hasDraft)
                              Container(
                                padding: EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.orange.shade100,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  'Draft',
                                  style: TextStyle(
                                    color: Colors.orange.shade800,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            SizedBox(width: 8),
                            Container(
                              padding: EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.red.shade100,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.add,
                                color: Colors.red.shade600,
                                size: 20,
                              ),
                            ),
                          ],
                        ),
                        onTap: () {
                          setState(() {
                            _selectedHallSlots.add(hallSlot);
                          });
                          Navigator.pop(context);
                          // Check slot availability after adding hall slot
                          _checkAndUpdateSlotAvailability();
                        },
                      ),
                    );
                  },
                ),
              ),
              SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Colors.grey.shade400),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: Text(
                        'Cancel',
                        style: TextStyle(color: Colors.grey.shade700),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _removeHallSlot(Map<String, String> hallSlot) {
    if (_selectedHallSlots.length > 1) {
      setState(() {
        _selectedHallSlots.remove(hallSlot);
      });
      // Check slot availability after removing hall slot
      _checkAndUpdateSlotAvailability();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text('At least one hall+slot combination must be selected')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = context.read<UserProvider>();
    final isCorporate = userProvider.currentUser?.branchId == 'all';

    return Scaffold(
      appBar: AppBar(
        title: Text('Edit Booking'),
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
        child: ListView(
          padding: EdgeInsets.all(16),
          children: [
            // Booking Details Section
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.calendar_today, color: Colors.red.shade400),
                      SizedBox(width: 8),
                      Text(
                        'Booking Details',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.red.shade600,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.red.shade200),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Date',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                DateFormat('MMM dd, yyyy')
                                    .format(widget.booking.date),
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.red.shade700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Container(
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.red.shade200),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Halls & Slots',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                widget.booking.hallSlots
                                    .map((hs) =>
                                        '${hs['hallName']} - ${hs['slotLabel']}')
                                    .join(", "),
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.red.shade700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      //icon: Icon(Icons.edit_calendar, size: 18),
                      label: Text("Change Date / Hall / Slot"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade400,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: () async {
                        print(
                            'DEBUG: Edit booking - Change Date/Hall/Slot button pressed');
                        print(
                            'DEBUG: Current booking date: ${widget.booking.date}');
                        print(
                            'DEBUG: Current booking hall slots: ${widget.booking.hallSlots}');

                        final result =
                            await Navigator.push<Map<String, dynamic>>(
                          context,
                          MaterialPageRoute(
                            builder: (_) => BanquetCalendarScreen(
                              initialDate: widget.booking.date,
                              isSelectionMode: true,
                            ),
                          ),
                        );
                        if (result != null) {
                          print(
                              'DEBUG: Edit booking - New selection received: $result');
                          setState(() {
                            widget.booking.date = result['date'];
                            // Update the hall slots to reflect the new selection
                            widget.booking.hallSlots = [
                              {
                                'hallName': result['hallName'],
                                'slotLabel': result['slotLabel'],
                              }
                            ];
                            // Also update the selected hall slots list to reflect the new selection
                            _selectedHallSlots = [
                              {
                                'hallName': result['hallName'],
                                'slotLabel': result['slotLabel'],
                              }
                            ];
                          });
                          print(
                              'DEBUG: Edit booking - Updated with new date: ${widget.booking.date}, hall slots: ${widget.booking.hallSlots}');
                          print(
                              'DEBUG: Edit booking - Updated selected hall slots: $_selectedHallSlots');

                          // Check slot availability after updating hall slots
                          _checkAndUpdateSlotAvailability();
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 16),
            // Selected Halls & Slots Section
            ChangeNotifierProvider<BanquetProvider>(
              create: (_) => BanquetProvider(branchId: widget.branchId),
              child: Consumer<BanquetProvider>(
                builder: (context, provider, child) {
                  return Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.room, color: Colors.red.shade400),
                            SizedBox(width: 8),
                            Text(
                              'Selected Halls & Slots',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.red.shade600,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 12),

                        // Display selected hall+slot combinations as chips
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _selectedHallSlots.map((hallSlot) {
                            final hasDraft = provider.hasDraftBookings(
                                widget.booking.date,
                                hallSlot['hallName'] ?? '',
                                hallSlot['slotLabel'] ?? '');

                            return Container(
                              padding: EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: hasDraft
                                    ? Colors.orange.shade100
                                    : Colors.red.shade100,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: hasDraft
                                      ? Colors.orange.shade300
                                      : Colors.red.shade300,
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.room,
                                    size: 16,
                                    color: hasDraft
                                        ? Colors.orange.shade700
                                        : Colors.red.shade700,
                                  ),
                                  SizedBox(width: 6),
                                  Text(
                                    '${hallSlot['hallName']} - ${hallSlot['slotLabel']}',
                                    style: TextStyle(
                                      color: hasDraft
                                          ? Colors.orange.shade800
                                          : Colors.red.shade800,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  if (_selectedHallSlots.length > 1) ...[
                                    SizedBox(width: 6),
                                    GestureDetector(
                                      onTap: () => _removeHallSlot(hallSlot),
                                      child: Icon(
                                        Icons.close,
                                        size: 16,
                                        color: hasDraft
                                            ? Colors.orange.shade700
                                            : Colors.red.shade700,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            );
                          }).toList(),
                        ),

                        // Show warning if any selected slots have draft bookings
                        if (_selectedHallSlots.any((hallSlot) =>
                            provider.hasDraftBookings(
                                widget.booking.date,
                                hallSlot['hallName'] ?? '',
                                hallSlot['slotLabel'] ?? '')))
                          Container(
                            margin: EdgeInsets.only(top: 12),
                            padding: EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.orange.shade200),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.info_outline,
                                    color: Colors.orange.shade600, size: 20),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Some selected slots have draft bookings. You can still confirm your booking.',
                                    style: TextStyle(
                                      color: Colors.orange.shade800,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                        // Show warning if slots are unavailable for confirmation
                        if (!_slotsAvailable && widget.booking.isDraft)
                          Container(
                            margin: EdgeInsets.only(top: 12),
                            padding: EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.red.shade200),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.error_outline,
                                    color: Colors.red.shade600, size: 20),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Some selected slots are no longer available. Please change your selection to confirm this booking.',
                                    style: TextStyle(
                                      color: Colors.red.shade800,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                        SizedBox(height: 12),

                        // Add Hall+Slot Button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            icon: provider.halls.isEmpty ||
                                    provider.slots.isEmpty
                                ? SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                          Colors.white),
                                    ),
                                  )
                                : Icon(Icons.add, size: 18),
                            label: Text(
                                provider.halls.isEmpty || provider.slots.isEmpty
                                    ? 'Loading...'
                                    : 'Add Hall & Slot'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red.shade400,
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            onPressed: (provider.halls.isEmpty ||
                                    provider.slots.isEmpty)
                                ? null
                                : () =>
                                    _showAddHallSlotDialog(context, provider),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            SizedBox(height: 16),
            // Customer Info Section
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.person, color: Colors.red.shade400),
                      SizedBox(width: 8),
                      Text(
                        'Customer Information',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.red.shade600,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  _buildTextField(
                    label: 'Customer Name',
                    controller: _nameController,
                    icon: Icons.person_outline,
                    isRequired: true,
                  ),
                  SizedBox(height: 12),
                  _buildTextField(
                    label: 'Phone Number',
                    controller: _phoneController,
                    icon: Icons.phone_outlined,
                    keyboardType: TextInputType.phone,
                    isRequired: true,
                    suffix: Row(
                      mainAxisSize: MainAxisSize.min,
                      // children: [
                      //   IconButton(
                      //     icon: Icon(Icons.message, color: Colors.red.shade400),
                      //     onPressed: () {
                      //       // Handle message action
                      //     },
                      //   ),
                      //   IconButton(
                      //     icon: Icon(Icons.call, color: Colors.red.shade400),
                      //     onPressed: () {
                      //       _callNumber(_phoneController.text.trim());
                      //     },
                      //   ),
                      // ],
                    ),
                  ),
                  SizedBox(height: 12),
                  _buildTextField(
                    label: 'Number of People (PAX)',
                    controller: _paxController,
                    icon: Icons.people_outline,
                    keyboardType: TextInputType.number,
                    isRequired: true,
                  ),
                  SizedBox(height: 12),
                  _buildTextField(
                    label: 'Callback Comment',
                    controller: _callbackController,
                    icon: Icons.comment_outlined,
                    maxLines: 3,
                  ),
                ],
              ),
            ),
            SizedBox(height: 16),
            // Payment Section
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.payment, color: Colors.red.shade400),
                      SizedBox(width: 8),
                      Text(
                        'Payment Information',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.red.shade600,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  _buildTextField(
                    label: 'Advance Amount Received',
                    controller: _advanceController,
                    icon: Icons.payment_outlined,
                    keyboardType: TextInputType.number,
                    onChanged: (val) {
                      setState(() {
                        _remainingAmount =
                            _totalAmount - (double.tryParse(val.trim()) ?? 0.0);
                      });
                    },
                    readOnly: !isCorporate,
                  ),
                  SizedBox(height: 12),
                  _buildTextField(
                    label: 'Total Amount Payable',
                    controller: _totalAmountController,
                    icon: Icons.account_balance_wallet_outlined,
                    keyboardType: TextInputType.number,
                    onChanged: (val) {
                      setState(() {
                        _totalAmount = double.tryParse(val.trim()) ?? 0.0;
                        _remainingAmount = _totalAmount -
                            (double.tryParse(_advanceController.text.trim()) ??
                                0.0);
                      });
                    },
                    readOnly: !isCorporate,
                  ),
                  SizedBox(height: 12),
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.calculate_outlined,
                            color: Colors.grey.shade600),
                        SizedBox(width: 8),
                        Text(
                          'Remaining Amount: ',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade700,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Spacer(),
                        Text(
                          '₹${_remainingAmount.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: _remainingAmount > 0
                                ? Colors.red.shade600
                                : Colors.green.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 16),
            // Menu Section
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.restaurant_menu, color: Colors.red.shade400),
                      SizedBox(width: 8),
                      Text(
                        'Menu Selection',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.red.shade600,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  FutureBuilder<List<Menu>>(
                    future: _fetchMenus(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return Center(child: CircularProgressIndicator());
                      }
                      if (snapshot.hasError) {
                        return Text('Error loading menus');
                      }
                      final menus = snapshot.data ?? [];
                      if (menus.isEmpty) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Text(
                            'No menus found. Please create one from Menu Management.',
                            style: TextStyle(color: Colors.redAccent),
                          ),
                        );
                      }

                      // Remove duplicates and ensure unique menus
                      final uniqueMenus = <Menu>[];
                      final seenNames = <String>{};
                      for (final menu in menus) {
                        if (!seenNames.contains(menu.name)) {
                          seenNames.add(menu.name);
                          uniqueMenus.add(menu);
                        }
                      }

                      // Find the matching menu from the unique list
                      Menu? selectedMenuFromList;
                      if (_selectedMenu != null) {
                        final matchingMenus = uniqueMenus
                            .where((m) => m.name == _selectedMenu!.name);
                        selectedMenuFromList = matchingMenus.isNotEmpty
                            ? matchingMenus.first
                            : null;
                      }

                      // If selected menu is not in the list, clear it
                      if (_selectedMenu != null &&
                          selectedMenuFromList == null) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          setState(() {
                            _selectedMenu = null;
                            _selectedItems.clear();
                          });
                        });
                      }

                      return Column(
                        children: [
                          DropdownButtonFormField<Menu>(
                            value: selectedMenuFromList,
                            decoration: InputDecoration(
                              labelText: 'Select Menu',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            items: uniqueMenus.map((menu) {
                              return DropdownMenuItem(
                                value: menu,
                                child: Text('${menu.name} - ₹${menu.price}'),
                              );
                            }).toList(),
                            onChanged: (Menu? newValue) {
                              setState(() {
                                _selectedMenu = newValue;
                                _selectedItems.clear();
                              });
                            },
                          ),
                          SizedBox(height: 12),
                          if (_selectedMenu != null)
                            TextButton.icon(
                              icon: Icon(Icons.edit),
                              label: Text('Edit Menu Selections'),
                              onPressed: () async {
                                final updated = await Navigator.push<
                                    Map<String, Set<String>>>(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => SelectMenuItemsPage(
                                      menu: _selectedMenu!,
                                      initialSelections: _selectedItems,
                                      branchId: widget.branchId,
                                    ),
                                  ),
                                );
                                if (updated != null) {
                                  setState(() {
                                    _selectedItems = updated;
                                  });
                                }
                              },
                            )
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
            SizedBox(height: 16),
            // Comments Section
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.note, color: Colors.red.shade400),
                      SizedBox(width: 8),
                      Text(
                        'Additional Comments',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.red.shade600,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12),
                  _buildTextField(
                    label: 'Comments',
                    controller: _commentsController,
                    icon: Icons.comment_outlined,
                    maxLines: 3,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: widget.booking.isDraft
            ? Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 50,
                      child: ElevatedButton(
                        onPressed:
                            (_isSaving || _isConfirming) ? null : _saveChanges,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey.shade300,
                          foregroundColor: Colors.grey.shade700,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 2,
                        ),
                        child: _isSaving
                            ? Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                          Colors.grey.shade700),
                                    ),
                                  ),
                                  SizedBox(width: 12),
                                  Text('Saving...'),
                                ],
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.save, size: 20),
                                  SizedBox(width: 8),
                                  Text(
                                    'Save Changes',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 50,
                      child: ElevatedButton(
                        onPressed:
                            (_isSaving || _isConfirming || !_slotsAvailable)
                                ? null
                                : _confirmBooking,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: !_slotsAvailable
                              ? Colors.grey.shade400
                              : Colors.green.shade600,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 2,
                        ),
                        child: _isConfirming
                            ? Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                          Colors.white),
                                    ),
                                  ),
                                  SizedBox(width: 12),
                                  Text('Confirming...'),
                                ],
                              )
                            : !_slotsAvailable
                                ? Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.block, size: 20),
                                      SizedBox(width: 8),
                                      Text(
                                        'Slots Unavailable',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  )
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.check_circle, size: 20),
                                      SizedBox(width: 8),
                                      Text(
                                        'Confirm Booking',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                      ),
                    ),
                  ),
                ],
              )
            : SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveChanges,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade400,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                  ),
                  child: _isSaving
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            ),
                            SizedBox(width: 12),
                            Text('Saving...'),
                          ],
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.save, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'Save Changes',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
      ),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && justMadeCall) {
      justMadeCall = false;
      Future.delayed(Duration(milliseconds: 500), () {
        showCallbackCommentDialog(context);
      });
    }
  }

  Future<void> showCallbackCommentDialog(BuildContext context) async {
    TextEditingController _commentController = TextEditingController();

    bool? saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Callback Comment'),
          content: TextField(
            controller: _commentController,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'Enter details about the call...',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(false);
              },
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (_commentController.text.trim().isNotEmpty) {
                  // Save comment logic here
                  Navigator.of(context).pop(true);
                }
              },
              child: Text('Save'),
            ),
          ],
        );
      },
    );

    if (saved != true) {
      _callbackController.text = _commentController.text;
      if (widget.notificationBloc != null) {
        widget.notificationBloc!.add(SendNotificationToAdminAfterTimer(
            bookingId: widget.docId, body: _commentController.text));
      }
      setState(() {});
      print('Comment not saved — start 15-minute timer');
    }
  }

  Future<void> _callNumber(String phoneNumber) async {
    final Uri phoneUri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(phoneUri)) {
      justMadeCall = true; // set flag before launching dialer
      await launchUrl(phoneUri);
    } else {
      // throw 'Could not launch $phoneNumber';
      print('Simulating call since no SIM found.');
      justMadeCall = true;

      // Simulate "returning from dialer" after a few seconds
      Future.delayed(Duration(seconds: 2), () {
        showCallbackCommentDialog(context);
      });
    }
  }

  Widget _buildTextField({
    required String label,
    TextEditingController? controller,
    IconData? icon,
    TextInputType? keyboardType,
    int maxLines = 1,
    bool isRequired = false,
    Function(String)? onChanged,
    Widget? suffix,
    bool readOnly = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 20, color: Colors.grey.shade600),
              SizedBox(width: 8),
            ],
            Text(
              label + (isRequired ? ' *' : ''),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade700,
              ),
            ),
          ],
        ),
        SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          onChanged: onChanged,
          readOnly: readOnly,
          decoration: InputDecoration(
            hintText: 'Enter ${label.toLowerCase()}',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.red.shade400, width: 2),
            ),
            filled: true,
            fillColor: Colors.grey.shade50,
            suffixIcon: suffix,
          ),
        ),
      ],
    );
  }

  Widget _buildCallbackTimePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.access_time, size: 20, color: Colors.grey.shade600),
            SizedBox(width: 8),
            Text(
              'Callback Time',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade700,
              ),
            ),
          ],
        ),
        SizedBox(height: 8),
        InkWell(
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: _callbackTime ?? DateTime.now(),
              firstDate: DateTime.now(),
              lastDate: DateTime.now().add(Duration(days: 365)),
              builder: (context, child) {
                return Theme(
                  data: Theme.of(context).copyWith(
                    colorScheme: ColorScheme.light(
                      primary: Colors.red.shade400,
                      onPrimary: Colors.white,
                      surface: Colors.white,
                      onSurface: Colors.grey.shade800,
                    ),
                    textButtonTheme: TextButtonThemeData(
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.red.shade400,
                      ),
                    ),
                    dialogTheme: DialogTheme(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 8,
                    ),
                  ),
                  child: child!,
                );
              },
            );
            if (picked != null) {
              final time = await showTimePicker(
                context: context,
                initialTime: TimeOfDay.now(),
                builder: (context, child) {
                  return Theme(
                    data: Theme.of(context).copyWith(
                      colorScheme: ColorScheme.light(
                        primary: Colors.red.shade400,
                        onPrimary: Colors.white,
                        surface: Colors.white,
                        onSurface: Colors.grey.shade800,
                      ),
                      textButtonTheme: TextButtonThemeData(
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.red.shade400,
                        ),
                      ),
                      dialogTheme: DialogTheme(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 8,
                      ),
                    ),
                    child: child!,
                  );
                },
              );
              if (time != null) {
                setState(() {
                  _callbackTime = DateTime(picked.year, picked.month,
                      picked.day, time.hour, time.minute);
                });
              }
            }
          },
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _callbackTime != null
                  ? Colors.red.shade50
                  : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: _callbackTime != null
                    ? Colors.red.shade200
                    : Colors.grey.shade300,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.access_time,
                  size: 20,
                  color: _callbackTime != null
                      ? Colors.red.shade400
                      : Colors.grey.shade600,
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _callbackTime == null
                        ? 'Select Callback Time'
                        : 'Callback: ${DateFormat('MMM dd, yyyy – kk:mm').format(_callbackTime!)}',
                    style: TextStyle(
                      fontSize: 14,
                      color: _callbackTime != null
                          ? Colors.red.shade700
                          : Colors.grey.shade700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class Tuple2<T1, T2> {
  final T1 item1;
  final T2 item2;
  Tuple2(this.item1, this.item2);
}
