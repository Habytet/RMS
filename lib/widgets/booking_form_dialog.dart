import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:token_manager/models/hall.dart';
import '../models/banquet_booking.dart';
import '../providers/banquet_provider.dart';

class BookingFormDialog extends StatefulWidget {
  final DateTime date;
  final String hallName;
  final String slotLabel;

  BookingFormDialog({
    required this.date,
    required this.hallName,
    required this.slotLabel,
  });

  @override
  State<BookingFormDialog> createState() => _BookingFormDialogState();
}

class _BookingFormDialogState extends State<BookingFormDialog> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _paxController = TextEditingController();
  final _amountController = TextEditingController();
  final _menuController = TextEditingController();
  final _totalAmountController = TextEditingController();
  final _commentsController = TextEditingController();

  void _submit({required bool isDraft}) {
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();
    final pax = int.tryParse(_paxController.text.trim()) ?? 0;
    final amount = double.tryParse(_amountController.text.trim()) ?? 0;
    final totalAmount = double.tryParse(_totalAmountController.text.trim()) ?? 0;
    final remaining = totalAmount - amount;
    final menu = _menuController.text.trim();
    final comments = _commentsController.text.trim();

    if (name.isEmpty || phone.isEmpty || menu.isEmpty || pax == 0 || totalAmount == 0) return;

    final booking = BanquetBooking(
      date: widget.date,
      hallInfos: <HallInfo>[],
      // hallName: widget.hallName,
      // slotLabel: widget.slotLabel,
      customerName: name,
      phone: phone,
      pax: pax,
      amount: amount,
      menu: menu,
      totalAmount: totalAmount,
      remainingAmount: remaining,
      comments: comments,
      callbackTime: null,
      isDraft: isDraft,
    );

    context.read<BanquetProvider>().createBooking(booking);
    Navigator.pop(context);
    Navigator.pop(context); // close bottom sheet too
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Book ${widget.hallName} @ ${widget.slotLabel}'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Date: ${widget.date.toLocal().toString().split(' ')[0]}'),
            TextField(controller: _nameController, decoration: InputDecoration(labelText: 'Customer Name')),
            TextField(controller: _phoneController, decoration: InputDecoration(labelText: 'Phone')),
            TextField(controller: _paxController, decoration: InputDecoration(labelText: 'PAX'), keyboardType: TextInputType.number),
            TextField(controller: _totalAmountController, decoration: InputDecoration(labelText: 'Total Amount'), keyboardType: TextInputType.number),
            TextField(controller: _amountController, decoration: InputDecoration(labelText: 'Amount Received (Advance)'), keyboardType: TextInputType.number),
            TextField(controller: _menuController, decoration: InputDecoration(labelText: 'Menu')),
            TextField(controller: _commentsController, decoration: InputDecoration(labelText: 'Comments')),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel')),
        OutlinedButton(onPressed: () => _submit(isDraft: true), child: Text('Save Draft')),
        ElevatedButton(onPressed: () => _submit(isDraft: false), child: Text('Confirm Booking')),
      ],
    );
  }
}