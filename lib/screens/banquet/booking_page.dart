import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:token_manager/screens/banquet/banquet_bloc.dart';
import 'package:token_manager/screens/banquet/banquet_event.dart';
import 'package:token_manager/screens/banquet/banquet_state.dart';

import '../../models/banquet_booking.dart';
import '../../models/menu.dart';
import '../../providers/banquet_provider.dart';
import 'select_menu_items_page.dart';

class BookingPage extends StatefulWidget {
  DateTime date;
  String branchId;
  BanquetBloc banquetBloc;
  BanquetProvider provider;

  BookingPage(
      {required this.date,
      required this.branchId,
      required this.banquetBloc,
      required this.provider});

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

  // CollectionReference getMenusCollection() {
  //   return FirebaseFirestore.instance
  //       .collection('branches')
  //       .doc(widget.branchId)
  //       .collection('halls')
  //       .doc(widget.hallName)
  //       .collection('menus');
  // }

  Future<List<Map<String, dynamic>>> fetchMenusAcrossHalls() async {
    final selectedHalls = widget.banquetBloc.selectedHalls;
    final branchId = widget.branchId;

    List<Map<String, dynamic>> allMenus = [];

    for (final hall in selectedHalls) {
      final collection = FirebaseFirestore.instance
          .collection('branches')
          .doc(branchId)
          .collection('halls')
          .doc(hall.name)
          .collection('menus');

      final snapshot = await collection.get();

      allMenus.addAll(snapshot.docs.map((doc) {
        final data = doc.data();
        data['hallName'] = hall.name; // Add context
        return data;
      }));
    }

    return allMenus;
  }


  List<Map<String, dynamic>> menusUpdated = <Map<String, dynamic>>[];
  @override
  void initState() {
    super.initState();
    fetchMenusAcrossHalls().then((value) {
      menusUpdated = value;
      setState(() {});
    });
  }

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

    if (_selectedMenu == null || name.isEmpty || phone.isEmpty || pax == 0)
      return;

    final menuString = _selectedMenu!.name +
        _selectedItems.entries
            .map((e) => '\n${e.key}: ${e.value.join(", ")}')
            .join();

    final booking = BanquetBooking(
        date: widget.date,
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
        hallInfos: widget.banquetBloc.selectedHalls);

    // Use a BanquetProvider for the correct branch
    final provider = BanquetProvider(branchId: widget.branchId);
    provider.createBooking(booking);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    // Fetch menus for the correct branch/hall

    return Scaffold(
      appBar: AppBar(title: Text('Booking')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            ElevatedButton.icon(
              icon: Icon(Icons.edit_calendar),
              label: Text("Change Date / Hall / Slot"),
              onPressed: () async {},
            ),
            Text('Date: ${DateFormat('yyyy-MM-dd').format(widget.date)}'),
            Text(widget.banquetBloc.selectedHallSlot()),
            OutlinedButton(
              onPressed: () => _openAvailabilityPopup(
                  context, DateTime.now(), widget.provider),
              child: Text('Add Extra Hall/Slot'),
            ),
            SizedBox(height: 12),
            TextField(
                controller: _nameController,
                decoration: InputDecoration(labelText: 'Customer Name')),
            TextField(
                controller: _phoneController,
                decoration: InputDecoration(labelText: 'Phone')),
            TextField(
              controller: _paxController,
              decoration: InputDecoration(labelText: 'PAX'),
              keyboardType: TextInputType.number,
              onChanged: (_) => _updateRemaining(),
            ),
            TextField(
              controller: _receivedController,
              decoration:
                  InputDecoration(labelText: 'Advance (Amount Received)'),
              keyboardType: TextInputType.number,
              onChanged: (_) => _updateRemaining(),
            ),
            TextField(
              decoration: InputDecoration(labelText: 'Total Amount Payable'),
              keyboardType: TextInputType.number,
              onChanged: (val) {
                setState(() {
                  _totalAmount = double.tryParse(val.trim()) ?? 0.0;
                  _remaining = _totalAmount -
                      (double.tryParse(_receivedController.text.trim()) ?? 0);
                });
              },
            ),
            SizedBox(height: 12),
            Text('Remaining Amount: ₹$_remaining',
                style: TextStyle(fontWeight: FontWeight.bold)),
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
                      _callbackTime = DateTime(picked.year, picked.month,
                          picked.day, time.hour, time.minute);
                    });
                  }
                }
              },
            ),
            SizedBox(height: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButton<Map<String, dynamic>>(
                  value: null,
                  hint: Text('Select Menu'),
                  isExpanded: true,
                  items: menusUpdated.map((menu) {
                    return DropdownMenuItem<Map<String, dynamic>>(
                      value: menu,
                      child: Text('${menu['name']} - ₹${menu['price']}+tax'),
                    );
                  }).toList(),
                  onChanged: (menu) {
                    // setState(() {
                    //   _selectedMenu = menu;
                    //   _selectedItems = {};
                    // });
                  },
                ),
                if (_selectedMenu != null) ...[
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Menu selected: ${_selectedMenu!.name}'),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    icon: Icon(Icons.edit),
                    label: Text('Edit Menu'),
                    onPressed: () async {
                      // final updated =
                      //     await Navigator.push<Map<String, Set<String>>>(
                      //   context,
                      //   MaterialPageRoute(
                      //     builder: (_) => SelectMenuItemsPage(
                      //       menu: _selectedMenu!,
                      //       initialSelections: _selectedItems,
                      //       branchId: widget.branchId,
                      //       hallName: widget.hallName,
                      //     ),
                      //   ),
                      // );
                      // if (updated != null) {
                      //   setState(() {
                      //     _selectedItems = updated;
                      //   });
                      // }
                    },
                  ),
                  if (_selectedItems.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Selected Items:',
                              style:
                              TextStyle(fontWeight: FontWeight.bold)),
                          ..._selectedItems.entries.map((e) =>
                              Text('${e.key}: ${e.value.join(", ")}')),
                        ],
                      ),
                    ),
                ],
              ],
            ),
            SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _submit(isDraft: false),
                    child: Text('Confirm Booking'),
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _submit(isDraft: true),
                    child: Text('Save as Draft'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _openAvailabilityPopup(
      BuildContext context, DateTime date, BanquetProvider provider) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return BlocBuilder(
          bloc: widget.banquetBloc,
          buildWhen: (preState, currState) =>
              currState is RefreshBottomSheetState,
          builder: (context, state) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 12,
                left: 16,
                right: 16,
                top: 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: SingleChildScrollView(
                      child: Column(
                        children: provider.halls.map((hall) {
                          final slots = provider.getSlotsForHall(hall.name);
                          return ExpansionTile(
                            title: Text(hall.name),
                            children: slots.map((slot) {
                              final booked = provider.isSlotBooked(
                                  date, hall.name, slot.label);
                              return ListTile(
                                title: Text(slot.label),
                                trailing: booked
                                    ? Text('Booked',
                                        style: TextStyle(color: Colors.red))
                                    : ElevatedButton(
                                        child: widget.banquetBloc
                                                .isSelectedSlots(
                                                    hallName: hall.name,
                                                    slot: slot.label)
                                            ? Text('Selected')
                                            : Text('Select'),
                                        onPressed: () => widget.banquetBloc.add(
                                            SelectHallSlotEvent(
                                                hallName: hall.name,
                                                slotName: slot.label)),
                                      ),
                              );
                            }).toList(),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {});
                      Navigator.pop(context); // Close the bottom sheet
                    },
                    child: const Text("Submit"),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
