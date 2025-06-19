import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../providers/banquet_provider.dart';
import '../../models/hall.dart';
import '../../models/slot.dart';

class BanquetCalendarScreen extends StatefulWidget {
  final DateTime? initialDate;

  const BanquetCalendarScreen({this.initialDate});

  @override
  State<BanquetCalendarScreen> createState() => _BanquetCalendarScreenState();
}

class _BanquetCalendarScreenState extends State<BanquetCalendarScreen> {
  late DateTime _focusedDay;
  DateTime? _selectedDay;

  @override
  void initState() {
    super.initState();
    _focusedDay = widget.initialDate ?? DateTime.now();
    _selectedDay = widget.initialDate;
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<BanquetProvider>();

    return Scaffold(
      appBar: AppBar(title: Text('Banquet Availability')),
      body: TableCalendar(
        firstDay: DateTime.utc(2023, 1, 1),
        lastDay: DateTime.utc(2030, 12, 31),
        focusedDay: _focusedDay,
        selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
        onDaySelected: (selected, focused) {
          setState(() {
            _selectedDay = selected;
            _focusedDay = focused;
          });
          _openAvailabilityPopup(context, selected);
        },
        calendarBuilders: CalendarBuilders(
          defaultBuilder: (context, day, _) {
            final isAvailable = _checkAnySlotAvailable(provider, day);
            final borderColor = isAvailable ? Colors.green : Colors.red;

            return Container(
              margin: EdgeInsets.all(4),
              decoration: BoxDecoration(
                border: Border.all(color: borderColor, width: 2),
                borderRadius: BorderRadius.circular(8),
              ),
              alignment: Alignment.center,
              child: Text('${day.day}'),
            );
          },
        ),
      ),
    );
  }

  bool _checkAnySlotAvailable(BanquetProvider provider, DateTime date) {
    for (var hall in provider.halls) {
      for (var slot in provider.getSlotsForHall(hall.name)) {
        if (!provider.isSlotBooked(date, hall.name, slot.label)) return true;
      }
    }
    return false;
  }

  void _openAvailabilityPopup(BuildContext context, DateTime date) {
    final provider = context.read<BanquetProvider>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 12,
          left: 16,
          right: 16,
          top: 16,
        ),
        child: Wrap(
          children: provider.halls.map((hall) {
            final slots = provider.getSlotsForHall(hall.name);
            return ExpansionTile(
              title: Text(hall.name),
              children: slots.map((slot) {
                final booked = provider.isSlotBooked(date, hall.name, slot.label);
                return ListTile(
                  title: Text(slot.label),
                  trailing: booked
                      ? Text('Booked', style: TextStyle(color: Colors.red))
                      : ElevatedButton(
                    child: Text('Select'),
                    onPressed: () {
                      Navigator.pop(context); // close popup
                      Navigator.pushNamed(
                        context,
                        '/banquet/book',
                        arguments: {
                          'date': date,
                          'hallName': hall.name,
                          'slotLabel': slot.label,
                        },
                      );
                    },
                  ),
                );
              }).toList(),
            );
          }).toList(),
        ),
      ),
    );
  }
}