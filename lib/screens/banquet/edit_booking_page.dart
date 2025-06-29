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
    final snapshot = await FirebaseFirestore.instance
        .collection('branches')
        .doc(widget.branchId)
        .collection('halls')
        .doc(widget.booking.hallName)
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
      appBar: AppBar(title: Text('Edit Booking')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            Text(
                'Date: ${DateFormat('yyyy-MM-dd').format(widget.booking.date)}'),
            Text('Hall: ${widget.booking.hallName}'),
            Text('Slot: ${widget.booking.slotLabel}'),
            ElevatedButton.icon(
              icon: Icon(Icons.edit_calendar),
              label: Text("Change Date / Hall / Slot"),
              onPressed: () async {
                final result = await Navigator.push<Map<String, dynamic>>(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        BanquetCalendarScreen(initialDate: widget.booking.date),
                  ),
                );
                if (result != null) {
                  setState(() {
                    widget.booking.date = result['date'];
                    widget.booking.hallName = result['hallName'];
                    widget.booking.slotLabel = result['slotLabel'];
                  });
                }
              },
            ),
            SizedBox(height: 12),
            TextField(
                controller: _nameController,
                decoration: InputDecoration(labelText: 'Customer Name')),
            TextField(
                controller: _phoneController,
                onChanged: (String value) {
                  setState(() {});
                },
                decoration: InputDecoration(
                    labelText: 'Phone',
                    suffix: _phoneController.text.length == 10
                        ? Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: InkWell(
                              onTap: () => _callNumber(_phoneController.text),
                              child: Icon(Icons.call),
                            ),
                          )
                        : null)),
            TextField(
                controller: _callbackController,
                onChanged: (String value) {
                  setState(() {});
                },
                decoration: InputDecoration(
                  labelText: 'Callback Comment',
                )),
            TextField(
              controller: _paxController,
              decoration: InputDecoration(labelText: 'PAX'),
              keyboardType: TextInputType.number,
            ),
            TextField(
              controller: _advanceController,
              decoration: InputDecoration(labelText: 'Advance Amount'),
              keyboardType: TextInputType.number,
              onChanged: (val) {
                setState(() {
                  _remainingAmount =
                      _totalAmount - (double.tryParse(val.trim()) ?? 0.0);
                });
              },
              readOnly: !isCorporate,
            ),
            TextField(
              controller: _totalAmountController,
              decoration: InputDecoration(labelText: 'Total Amount'),
              keyboardType: TextInputType.number,
              onChanged: (val) {
                setState(() {
                  _totalAmount = double.tryParse(val.trim()) ?? 0.0;
                  _remainingAmount = _totalAmount -
                      (double.tryParse(_advanceController.text.trim()) ?? 0.0);
                });
              },
              readOnly: !isCorporate,
            ),
            SizedBox(height: 8),
            Text('Remaining Amount: ₹$_remainingAmount',
                style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 12),
            TextField(
                controller: _commentsController,
                decoration: InputDecoration(labelText: 'Comments')),
            ListTile(
              title: Text(_callbackTime == null
                  ? 'Select Callback Time'
                  : 'Callback: ${DateFormat('yyyy-MM-dd – kk:mm').format(_callbackTime!)}'),
              trailing: Icon(Icons.access_time),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _callbackTime ?? DateTime.now(),
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(Duration(days: 365)),
                );
                if (picked != null) {
                  final time = await showTimePicker(
                    context: context,
                    initialTime: TimeOfDay.now(),
                  );
                  if (time != null) {
                    setState(() {
                      _callbackTime = DateTime(picked.year, picked.month,
                          picked.day, time.hour, time.minute);
                    });
                  }
                }
              },
            ),
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
                          child: Text('${menu.name} - ₹${menu.price}+tax'),
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
                          final updated =
                              await Navigator.push<Map<String, Set<String>>>(
                            context,
                            MaterialPageRoute(
                              builder: (_) => SelectMenuItemsPage(
                                menu: _selectedMenu!,
                                initialSelections: _selectedItems,
                                branchId: widget.branchId,
                                hallName: widget.booking.hallName,
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
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _saveChanges,
              child: Text('Save Changes'),
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
}

class Tuple2<T1, T2> {
  final T1 item1;
  final T2 item2;
  Tuple2(this.item1, this.item2);
}
