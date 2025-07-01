import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:token_manager/screens/banquet/banquet_bloc.dart';
import 'package:token_manager/screens/banquet/banquet_event.dart';
import 'package:token_manager/screens/banquet/banquet_state.dart';

import '../../providers/banquet_provider.dart';
import '../../models/hall.dart';
import '../../models/slot.dart';
import '../../providers/user_provider.dart';
import '../../screens/banquet/booking_page.dart';

class BanquetCalendarScreen extends StatefulWidget {
  final DateTime? initialDate;

  const BanquetCalendarScreen({this.initialDate});

  @override
  State<BanquetCalendarScreen> createState() => _BanquetCalendarScreenState();
}

class _BanquetCalendarScreenState extends State<BanquetCalendarScreen> {
  late DateTime _focusedDay;
  DateTime? _selectedDay;
  String? _selectedBranchId;
  final BanquetBloc _bloc = BanquetBloc();

  @override
  void initState() {
    super.initState();
    _focusedDay = widget.initialDate ?? DateTime.now();
    _selectedDay = widget.initialDate;
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

    return BlocProvider(
        lazy: false,
        create: (BuildContext context) => _bloc,
        child: ChangeNotifierProvider<BanquetProvider>(
          key: ValueKey(_selectedBranchId),
          create: (_) => BanquetProvider(branchId: _selectedBranchId!),
          child: Consumer<BanquetProvider>(
            builder: (context, provider, _) {
              return Scaffold(
                appBar: AppBar(title: Text('Banquet Availability')),
                body: Column(
                  children: [
                    if (isCorporate)
                      Padding(
                        padding: const EdgeInsets.all(12.0),
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
                    Expanded(
                      child: TableCalendar(
                        firstDay: DateTime.utc(2023, 1, 1),
                        lastDay: DateTime.utc(2030, 12, 31),
                        focusedDay: _focusedDay,
                        selectedDayPredicate: (day) =>
                            isSameDay(_selectedDay, day),
                        onDaySelected: (selected, focused) {
                          setState(() {
                            _selectedDay = selected;
                            _focusedDay = focused;
                          });
                          _openAvailabilityPopup(context, selected, provider);
                        },
                        calendarBuilders: CalendarBuilders(
                          defaultBuilder: (context, day, _) {
                            final color = _getDayBookingColor(provider, day);
                            return Container(
                              margin: EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                border: Border.all(color: color, width: 2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              alignment: Alignment.center,
                              child: Text('${day.day}'),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ));
  }

  bool _checkAnySlotAvailable(BanquetProvider provider, DateTime date) {
    for (var hall in provider.halls) {
      for (var slot in provider.getSlotsForHall(hall.name)) {
        if (!provider.isSlotBooked(date, hall.name, slot.label)) return true;
      }
    }
    return false;
  }

  void _openAvailabilityPopup(
      BuildContext context, DateTime date, BanquetProvider provider) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return BlocBuilder(
          bloc: _bloc,
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
                                  child: _bloc.isSelectedSlots(
                                      hallName: hall.name,
                                      slot: slot.label)
                                      ? Text('Selected')
                                      : Text('Select'),
                                  onPressed: () => _bloc.add(
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
                      Navigator.pop(context); // Close the bottom sheet
                      if (_bloc.selectedHalls.isNotEmpty) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => BookingPage(
                              date: date,
                              banquetBloc: _bloc,
                              branchId: _selectedBranchId!, provider: provider,
                            ),
                          ),
                        );
                      }
                      // Your submit logic here
                      print("Selected slots: ${_bloc.selectedHalls}");
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


  // Returns green if all slots free, yellow if some booked, red if all booked
  Color _getDayBookingColor(BanquetProvider provider, DateTime date) {
    int totalSlots = 0;
    int bookedSlots = 0;
    for (var hall in provider.halls) {
      final slots = provider.getSlotsForHall(hall.name);
      totalSlots += slots.length;
      for (var slot in slots) {
        if (provider.isSlotBooked(date, hall.name, slot.label)) bookedSlots++;
      }
    }
    if (totalSlots == 0) return Colors.green; // No slots defined
    if (bookedSlots == 0) return Colors.green;
    if (bookedSlots == totalSlots) return Colors.red;
    return Colors.yellow;
  }
}
