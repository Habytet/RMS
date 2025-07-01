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

    _parseMenu(widget.booking.menu).then((parsed) {
      setState(() {
        _selectedMenu = parsed.item1;
        _selectedItems = parsed.item2;
      });
    });
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

  void _saveChanges() {
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
      ..menu = _selectedMenu!.name +
          _selectedItems.entries
              .map((e) => '\n${e.key}: ${e.value.join(", ")}')
              .join();

    context.read<BanquetProvider>().updateBooking(
          widget.docId, // ← pass the doc ID
          updated,
        );
    Navigator.pop(context);
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
                          });
                          print(
                              'DEBUG: Edit booking - Updated with new date: ${widget.booking.date}, hall slots: ${widget.booking.hallSlots}');
                        }
                      },
                    ),
                  ),
                ],
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
                        'Customer Info',
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
                    onChanged: (String value) {
                      setState(() {});
                    },
                    suffix: _phoneController.text.length == 10
                        ? Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: InkWell(
                              onTap: () => _callNumber(_phoneController.text),
                              child:
                                  Icon(Icons.call, color: Colors.red.shade400),
                            ),
                          )
                        : null,
                  ),
                  SizedBox(height: 12),
                  _buildTextField(
                    label: 'Callback Comment',
                    controller: _callbackController,
                    icon: Icons.comment_outlined,
                    onChanged: (String value) {
                      setState(() {});
                    },
                  ),
                  SizedBox(height: 12),
                  _buildTextField(
                    label: 'Number of Guests (PAX)',
                    controller: _paxController,
                    icon: Icons.people_outline,
                    keyboardType: TextInputType.number,
                    isRequired: true,
                  ),
                  SizedBox(height: 12),
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
                      color: _remainingAmount > 0
                          ? Colors.orange.shade50
                          : Colors.green.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _remainingAmount > 0
                            ? Colors.orange.shade200
                            : Colors.green.shade200,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _remainingAmount > 0
                              ? Icons.warning_outlined
                              : Icons.check_circle_outline,
                          color: _remainingAmount > 0
                              ? Colors.orange.shade600
                              : Colors.green.shade600,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Remaining Amount: ₹${_remainingAmount.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: _remainingAmount > 0
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
            // Additional Info Section
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
                      Icon(Icons.comment, color: Colors.red.shade400),
                      SizedBox(width: 8),
                      Text(
                        'Additional Info',
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
                    label: 'Comments',
                    controller: _commentsController,
                    icon: Icons.comment_outlined,
                    maxLines: 3,
                  ),
                  SizedBox(height: 12),
                  _buildCallbackTimePicker(),
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
                      Icon(Icons.menu, color: Colors.red.shade400),
                      SizedBox(width: 8),
                      Text(
                        'Menu',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.red.shade600,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12),
                  FutureBuilder<List<Menu>>(
                    future: _fetchMenus(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
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
                      if (_selectedMenu != null) {
                        final match = menus
                            .where((m) => m.name == _selectedMenu!.name)
                            .toList();
                        if (match.length == 1) {
                          _selectedMenu = match.first;
                        } else {
                          _selectedMenu = null;
                        }
                      }
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          DropdownButton<Menu>(
                            value: _selectedMenu,
                            hint: Text('Select Menu'),
                            isExpanded: true,
                            items: menus.map((menu) {
                              return DropdownMenuItem<Menu>(
                                value: menu,
                                child:
                                    Text('${menu.name} - ₹${menu.price}+tax'),
                              );
                            }).toList(),
                            onChanged: (menu) {
                              setState(() {
                                _selectedMenu = menu;
                                _selectedItems = {};
                              });
                            },
                          ),
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
            // Action Buttons
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
                      Icon(Icons.save, color: Colors.red.shade400),
                      SizedBox(width: 8),
                      Text(
                        'Action',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.red.shade600,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _saveChanges,
                      child: Text('Save Changes'),
                    ),
                  ),
                ],
              ),
            ),
          ],
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
