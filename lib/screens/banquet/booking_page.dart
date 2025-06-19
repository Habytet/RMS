import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';

import '../../models/banquet_booking.dart';
import '../../models/menu.dart';
import '../../providers/banquet_provider.dart';
import 'select_menu_items_page.dart';
import 'banquet_calendar_screen.dart';

class BookingPage extends StatefulWidget {
  DateTime date;
  String hallName;
  String slotLabel;

  BookingPage({
    required this.date,
    required this.hallName,
    required this.slotLabel,
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

  void _updateRemaining() {
    final received = double.tryParse(_receivedController.text.trim()) ?? 0.0;
    setState(() {
      _remaining = _totalAmount - received;
    });
  }

  void _submit({required bool isDraft}) {
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();
    final pax = int.tryParse(_paxController.text.trim()) ?? 0;
    final received = double.tryParse(_receivedController.text.trim()) ?? 0;
    final comments = _commentsController.text.trim();

    if (_selectedMenu == null || name.isEmpty || phone.isEmpty || pax == 0) return;

    final menuString = _selectedMenu!.name +
        _selectedItems.entries.map((e) => '\n${e.key}: ${e.value.join(", ")}').join();

    final booking = BanquetBooking(
      date: widget.date,
      hallName: widget.hallName,
      slotLabel: widget.slotLabel,
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

    context.read<BanquetProvider>().createBooking(booking);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final menus = Hive.box<Menu>('menus').values.toList();

    return Scaffold(
      appBar: AppBar(title: Text('Booking for ${widget.hallName} - ${widget.slotLabel}')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            ElevatedButton.icon(
              icon: Icon(Icons.edit_calendar),
              label: Text("Change Date / Hall / Slot"),
              onPressed: () async {
                final result = await Navigator.push<Map<String, dynamic>>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => BanquetCalendarScreen(initialDate: widget.date),
                  ),
                );
                if (result != null) {
                  setState(() {
                    widget.date = result['date'];
                    widget.hallName = result['hallName'];
                    widget.slotLabel = result['slotLabel'];
                  });
                }
              },
            ),
            Text('Date: ${DateFormat('yyyy-MM-dd').format(widget.date)}'),
            Text('Hall: ${widget.hallName}'),
            Text('Slot: ${widget.slotLabel}'),
            SizedBox(height: 12),
            TextField(controller: _nameController, decoration: InputDecoration(labelText: 'Customer Name')),
            TextField(controller: _phoneController, decoration: InputDecoration(labelText: 'Phone')),
            TextField(
              controller: _paxController,
              decoration: InputDecoration(labelText: 'PAX'),
              keyboardType: TextInputType.number,
              onChanged: (_) => _updateRemaining(),
            ),
            TextField(
              controller: _receivedController,
              decoration: InputDecoration(labelText: 'Advance (Amount Received)'),
              keyboardType: TextInputType.number,
              onChanged: (_) => _updateRemaining(),
            ),
            TextField(
              decoration: InputDecoration(labelText: 'Total Amount Payable'),
              keyboardType: TextInputType.number,
              onChanged: (val) {
                setState(() {
                  _totalAmount = double.tryParse(val.trim()) ?? 0.0;
                  _remaining = _totalAmount - (double.tryParse(_receivedController.text.trim()) ?? 0);
                });
              },
            ),
            SizedBox(height: 12),
            Text('Remaining Amount: ₹$_remaining', style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 12),
            TextField(
              controller: _commentsController,
              maxLines: 2,
              decoration: InputDecoration(labelText: 'Comments'),
            ),
            SizedBox(height: 12),
            ListTile(
              title: Text(_callbackTime == null
                  ? 'Select Callback Time'
                  : 'Callback: ${DateFormat('yyyy-MM-dd – kk:mm').format(_callbackTime!)}'),
              trailing: Icon(Icons.access_time),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: DateTime.now(),
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
                      _callbackTime = DateTime(picked.year, picked.month, picked.day, time.hour, time.minute);
                    });
                  }
                }
              },
            ),
            SizedBox(height: 12),
            if (menus.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'No menus found. Please create one from Menu Management.',
                  style: TextStyle(color: Colors.redAccent),
                ),
              )
            else ...[
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
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    icon: Icon(Icons.edit),
                    label: Text("Edit Menu Selections"),
                    onPressed: () async {
                      final updated = await Navigator.push<Map<String, Set<String>>>(
                        context,
                        MaterialPageRoute(
                          builder: (_) => SelectMenuItemsPage(
                            menu: _selectedMenu!,
                            initialSelections: _selectedItems,
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
                ),
            ],
            SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _submit(isDraft: true),
                    child: Text('Save as Draft'),
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _submit(isDraft: false),
                    child: Text('Confirm Booking'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}