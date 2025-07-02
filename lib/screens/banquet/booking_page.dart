import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';

import '../../models/banquet_booking.dart';
import '../../models/menu.dart';
import '../../providers/banquet_provider.dart';
import 'select_menu_items_page.dart';
import 'banquet_calendar_screen.dart';

class BookingPage extends StatefulWidget {
  DateTime date;
  String hallName;
  String slotLabel;
  String branchId;

  BookingPage({
    required this.date,
    required this.hallName,
    required this.slotLabel,
    required this.branchId,
  });

  @override
  State<BookingPage> createState() => _BookingPageState();
}

class _BookingPageState extends State<BookingPage> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _paxController = TextEditingController();
  final _receivedController = TextEditingController();
  final _commentsController = TextEditingController();

  double _remaining = 0.0;
  double _totalAmount = 0.0;
  DateTime? _callbackTime;

  Menu? _selectedMenu;
  Map<String, Set<String>> _selectedItems = {};

  // New: List to store selected hall+slot combinations
  List<Map<String, String>> _selectedHallSlots = [];

  // Track if this is an existing draft booking (only when explicitly saved as draft)
  String? _existingDraftId;
  bool _isUpdatingDraft = false;

  // Focus node to prevent unwanted focus
  final FocusNode _dummyFocusNode = FocusNode();

  CollectionReference getMenusCollection() {
    // Use branch-level menus instead of hall-level
    return FirebaseFirestore.instance
        .collection('branches')
        .doc(widget.branchId)
        .collection('menus');
  }

  @override
  void initState() {
    super.initState();
    // Initialize with the initially selected hall+slot
    _selectedHallSlots = [
      {
        'hallName': widget.hallName,
        'slotLabel': widget.slotLabel,
      }
    ];
  }

  void _updateRemaining() {
    final received = double.tryParse(_receivedController.text.trim()) ?? 0.0;
    setState(() {
      _remaining = _totalAmount - received;
    });
  }

  void _submit({required bool isDraft}) async {
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();
    final pax = int.tryParse(_paxController.text.trim()) ?? 0;
    final received = double.tryParse(_receivedController.text.trim()) ?? 0;
    final comments = _commentsController.text.trim();

    if (name.isEmpty ||
        phone.isEmpty ||
        pax == 0 ||
        _selectedHallSlots.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please fill in all required fields')),
      );
      return;
    }

    final menuString = _selectedMenu != null
        ? _selectedMenu!.name +
            _selectedItems.entries
                .map((e) => '\n${e.key}: ${e.value.join(", ")}')
                .join()
        : '';

    final booking = BanquetBooking(
      date: widget.date,
      hallSlots: _selectedHallSlots, // Updated to use hallSlots list
      customerName: name,
      phone: phone,
      pax: pax,
      amount: received,
      totalAmount: _totalAmount,
      remainingAmount: _remaining,
      comments: comments,
      callbackTime: _callbackTime,
      menu: menuString,
      isDraft: isDraft,
    );

    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.red.shade400),
            ),
            SizedBox(width: 16),
            Text(_isUpdatingDraft
                ? 'Updating booking...'
                : 'Creating booking...'),
          ],
        ),
      ),
    );

    try {
      // Get the provider from context
      final provider = context.read<BanquetProvider>();
      String? bookingId;

      if (_isUpdatingDraft && _existingDraftId != null) {
        // Update existing draft booking
        print('DEBUG: Updating existing draft booking: $_existingDraftId');
        await provider.updateBooking(_existingDraftId!, booking);
        bookingId = _existingDraftId;
      } else {
        // Create new booking
        print('DEBUG: Creating new booking');
        bookingId = await provider.createBooking(booking);

        // If this is a draft, store the ID for future updates
        if (isDraft && bookingId != null) {
          _existingDraftId = bookingId;
          _isUpdatingDraft = true;
          print('DEBUG: Stored draft booking ID: $bookingId');
        }
      }

      // Close loading dialog
      Navigator.pop(context);

      if (bookingId != null) {
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Booking ${isDraft ? 'saved as draft' : 'confirmed'} successfully!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );

        // Navigate back
        Navigator.pop(context);
      } else {
        // Show error message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create booking. Please try again.'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      // Close loading dialog
      Navigator.pop(context);

      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error creating booking: $e'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  void _showAddHallSlotDialog(BuildContext context, BanquetProvider provider) {
    // Add debug logging
    print('DEBUG: _showAddHallSlotDialog called');
    print('DEBUG: Selected hall slots: $_selectedHallSlots');
    print('DEBUG: Provider halls: ${provider.halls.length}');
    print('DEBUG: Provider slots: ${provider.slots.length}');

    final availableHallSlots = provider.getAvailableHallSlotsExcluding(
        widget.date, _selectedHallSlots);

    print(
        'DEBUG: Available hall slots (excluding selected): ${availableHallSlots.length}');

    if (availableHallSlots.isEmpty) {
      // Show more detailed error message
      final allAvailable = provider.getAvailableHallSlots(widget.date);
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
                        widget.date,
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
    // Fetch menus for the correct branch/hall
    final menusCollection = getMenusCollection();

    return Consumer<BanquetProvider>(
      builder: (context, provider, _) {
        return Scaffold(
          appBar: AppBar(
            title: Text('New Booking'),
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
                // Date and Change Button Section
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
                          Icon(Icons.calendar_today,
                              color: Colors.red.shade400),
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
                      SizedBox(height: 12),
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
                                        .format(widget.date),
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
                                    'Time',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    widget.slotLabel,
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
                          icon: Icon(Icons.edit_calendar, size: 18),
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
                                'DEBUG: Change Date/Hall/Slot button pressed');
                            print('DEBUG: Current date: ${widget.date}');
                            print('DEBUG: Current hall: ${widget.hallName}');
                            print('DEBUG: Current slot: ${widget.slotLabel}');

                            final result =
                                await Navigator.push<Map<String, dynamic>>(
                              context,
                              MaterialPageRoute(
                                builder: (_) => BanquetCalendarScreen(
                                  initialDate: widget.date,
                                  isSelectionMode: true,
                                ),
                              ),
                            );
                            if (result != null) {
                              print('DEBUG: New selection received: $result');
                              setState(() {
                                widget.date = result['date'];
                                widget.hallName = result['hallName'];
                                widget.slotLabel = result['slotLabel'];
                                widget.branchId =
                                    result['branchId'] ?? widget.branchId;

                                // Update the selected hall slots to reflect the new selection
                                _selectedHallSlots = [
                                  {
                                    'hallName': widget.hallName,
                                    'slotLabel': widget.slotLabel,
                                  }
                                ];
                              });
                              print(
                                  'DEBUG: Updated booking with new date: ${widget.date}, hall: ${widget.hallName}, slot: ${widget.slotLabel}');
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 16),

                // Hall & Slot Selection Section
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
                              widget.date,
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
                              widget.date,
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

                      SizedBox(height: 12),

                      // Add Hall+Slot Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          icon: Icon(Icons.add, size: 18),
                          label: Text('Add Hall & Slot'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red.shade400,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onPressed: () =>
                              _showAddHallSlotDialog(context, provider),
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 16),

                // Customer Information Section
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
                        controller: _nameController,
                        label: 'Customer Name',
                        icon: Icons.person_outline,
                        isRequired: true,
                      ),
                      SizedBox(height: 12),
                      _buildTextField(
                        controller: _phoneController,
                        label: 'Phone Number',
                        icon: Icons.phone_outlined,
                        keyboardType: TextInputType.phone,
                        isRequired: true,
                      ),
                      SizedBox(height: 12),
                      _buildTextField(
                        controller: _paxController,
                        label: 'Number of Guests (PAX)',
                        icon: Icons.people_outline,
                        keyboardType: TextInputType.number,
                        isRequired: true,
                        onChanged: (_) => _updateRemaining(),
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 16),

                // Financial Information Section
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
                          Icon(Icons.attach_money, color: Colors.red.shade400),
                          SizedBox(width: 8),
                          Text(
                            'Financial Details',
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
                        controller: _receivedController,
                        label: 'Advance Amount Received',
                        icon: Icons.payment_outlined,
                        keyboardType: TextInputType.number,
                        onChanged: (_) => _updateRemaining(),
                      ),
                      SizedBox(height: 12),
                      _buildTextField(
                        label: 'Total Amount Payable',
                        icon: Icons.account_balance_wallet_outlined,
                        keyboardType: TextInputType.number,
                        onChanged: (val) {
                          setState(() {
                            _totalAmount = double.tryParse(val.trim()) ?? 0.0;
                            _remaining = _totalAmount -
                                (double.tryParse(
                                        _receivedController.text.trim()) ??
                                    0);
                          });
                        },
                      ),
                      SizedBox(height: 12),
                      Container(
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _remaining > 0
                              ? Colors.orange.shade50
                              : Colors.green.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _remaining > 0
                                ? Colors.orange.shade200
                                : Colors.green.shade200,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _remaining > 0
                                  ? Icons.warning_outlined
                                  : Icons.check_circle_outline,
                              color: _remaining > 0
                                  ? Colors.orange.shade600
                                  : Colors.green.shade600,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Remaining Amount: ₹${_remaining.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: _remaining > 0
                                    ? Colors.orange.shade800
                                    : Colors.green.shade800,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 16),

                // Additional Information Section
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
                          Icon(Icons.note_add, color: Colors.red.shade400),
                          SizedBox(width: 8),
                          Text(
                            'Additional Information',
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
                        controller: _commentsController,
                        label: 'Comments',
                        icon: Icons.comment_outlined,
                        maxLines: 3,
                      ),
                      SizedBox(height: 12),
                      _buildCallbackTimePicker(),
                    ],
                  ),
                ),

                SizedBox(height: 16),

                // Menu Selection Section
                StreamBuilder<QuerySnapshot>(
                  stream: menusCollection.snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
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
                        child: Text(
                          'Error loading menus.',
                          style: TextStyle(color: Colors.red.shade600),
                        ),
                      );
                    }
                    if (snapshot.connectionState == ConnectionState.waiting) {
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
                        child: Center(
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.red.shade400),
                          ),
                        ),
                      );
                    }
                    final menus = snapshot.data!.docs
                        .map((doc) =>
                            Menu.fromMap(doc.data() as Map<String, dynamic>))
                        .toList();
                    if (menus.isEmpty) {
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
                        child: Text(
                          'No menus found. Please create one from Menu Management.',
                          style: TextStyle(color: Colors.red.shade600),
                        ),
                      );
                    }
                    // If the selected menu is no longer in the list, clear it (avoid setState in build)
                    if (_selectedMenu != null &&
                        !menus.any((m) => m.name == _selectedMenu!.name)) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) setState(() => _selectedMenu = null);
                      });
                    }
                    // Fix: Safely get the selected menu for the dropdown value
                    Menu? selectedMenu;
                    try {
                      selectedMenu = menus
                          .firstWhere((m) => m.name == _selectedMenu?.name);
                    } catch (_) {
                      selectedMenu = null;
                    }
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
                              Icon(Icons.restaurant_menu,
                                  color: Colors.red.shade400),
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
                          // Simple dropdown that appears inline
                          DropdownButtonFormField<Menu>(
                            value: selectedMenu,
                            decoration: InputDecoration(
                              labelText: 'Select Menu (Optional)',
                              labelStyle: TextStyle(color: Colors.red.shade400),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide:
                                    BorderSide(color: Colors.red.shade200),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide:
                                    BorderSide(color: Colors.red.shade200),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(
                                    color: Colors.red.shade400, width: 2),
                              ),
                              filled: true,
                              fillColor: Colors.red.shade50,
                            ),
                            items: menus.map((Menu menu) {
                              return DropdownMenuItem<Menu>(
                                value: menu,
                                child:
                                    Text('${menu.name} - ₹${menu.price}+tax'),
                              );
                            }).toList(),
                            onChanged: (Menu? newValue) {
                              // Prevent any focus restoration by focusing on a dummy node
                              _dummyFocusNode.requestFocus();
                              setState(() {
                                _selectedMenu = newValue;
                                _selectedItems = {};
                              });
                            },
                          ),
                          if (_selectedMenu != null) ...[
                            SizedBox(height: 12),
                            Container(
                              padding: EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.green.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border:
                                    Border.all(color: Colors.green.shade200),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.check_circle,
                                      color: Colors.green.shade600),
                                  SizedBox(width: 8),
                                  Text(
                                    'Menu selected: ${_selectedMenu!.name}',
                                    style: TextStyle(
                                      color: Colors.green.shade800,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(height: 12),
                            ElevatedButton.icon(
                              //icon: Icon(Icons.edit, size: 18),
                              label: Text('Edit Menu Items'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue.shade600,
                                foregroundColor: Colors.white,
                                padding: EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
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
                            ),
                            if (_selectedItems.isNotEmpty) ...[
                              SizedBox(height: 12),
                              Text(
                                'Selected Items:',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red.shade600,
                                ),
                              ),
                              SizedBox(height: 8),
                              ..._selectedItems.entries.map((e) => Container(
                                    margin: EdgeInsets.only(bottom: 4),
                                    padding: EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade50,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      '${e.key}: ${e.value.join(", ")}',
                                      style: TextStyle(fontSize: 14),
                                    ),
                                  )),
                            ],
                          ],
                        ],
                      ),
                    );
                  },
                ),

                SizedBox(height: 24),

                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => _submit(isDraft: false),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade400,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(
                          'Confirm Booking',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _submit(isDraft: true),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: Colors.orange.shade400),
                          foregroundColor: Colors.orange.shade600,
                          padding: EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(
                          'Save as Draft',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                // Hidden focus node to prevent unwanted focus
                Focus(
                  focusNode: _dummyFocusNode,
                  child: SizedBox.shrink(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTextField({
    required String label,
    TextEditingController? controller,
    IconData? icon,
    TextInputType? keyboardType,
    int maxLines = 1,
    bool isRequired = false,
    Function(String)? onChanged,
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
              initialDate: DateTime.now(),
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
