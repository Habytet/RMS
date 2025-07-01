import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../providers/banquet_provider.dart';
import '../../models/hall.dart';
import '../../models/slot.dart';
import '../../providers/user_provider.dart';
import '../../screens/banquet/booking_page.dart';

class BanquetCalendarScreen extends StatefulWidget {
  final DateTime? initialDate;
  final bool isSelectionMode;

  const BanquetCalendarScreen({
    Key? key,
    this.initialDate,
    this.isSelectionMode = false,
  }) : super(key: key);

  @override
  State<BanquetCalendarScreen> createState() => _BanquetCalendarScreenState();
}

class _BanquetCalendarScreenState extends State<BanquetCalendarScreen> {
  late DateTime _focusedDay;
  DateTime? _selectedDay;
  String? _selectedBranchId;

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
      return Scaffold(
        appBar: AppBar(
          title: Text('Banquet Availability'),
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
          return Scaffold(
            appBar: AppBar(
              title: Text(
                'Banquet Availability',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                ),
              ),
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
                  if (isCorporate)
                    Container(
                      margin: EdgeInsets.all(16),
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
                              Icon(Icons.business, color: Colors.red.shade400),
                              SizedBox(width: 8),
                              Text(
                                'Select Branch',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.red.shade600,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            value: _selectedBranchId,
                            decoration: InputDecoration(
                              hintText: 'Choose a branch',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide:
                                    BorderSide(color: Colors.grey.shade300),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide:
                                    BorderSide(color: Colors.grey.shade300),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(
                                    color: Colors.red.shade400, width: 2),
                              ),
                              filled: true,
                              fillColor: Colors.grey.shade50,
                              contentPadding: EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 12),
                            ),
                            items: [
                              ...branches
                                  .where((b) => b.id != 'all')
                                  .map((b) => DropdownMenuItem(
                                        value: b.id,
                                        child: Text(
                                          b.name,
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.grey.shade800,
                                          ),
                                        ),
                                      )),
                            ],
                            onChanged: (value) {
                              setState(() {
                                _selectedBranchId = value;
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                  Container(
                    margin: EdgeInsets.symmetric(horizontal: 16),
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
                              'Availability Calendar',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.red.shade600,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 16),
                        _buildLegend(),
                        SizedBox(height: 16),
                        TableCalendar(
                          firstDay: DateTime.now().subtract(
                              Duration(days: 1)), // Allow today and future
                          lastDay: DateTime.utc(2030, 12, 31),
                          focusedDay: _focusedDay,
                          selectedDayPredicate: (day) =>
                              isSameDay(_selectedDay, day),
                          onDaySelected: (selected, focused) {
                            // Only allow selection of today or future dates
                            final today = DateTime.now();
                            final todayStart =
                                DateTime(today.year, today.month, today.day);
                            final selectedStart = DateTime(
                                selected.year, selected.month, selected.day);

                            if (selectedStart.isBefore(todayStart)) {
                              // Past date selected - show error message
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Row(
                                    children: [
                                      Icon(Icons.warning, color: Colors.white),
                                      SizedBox(width: 8),
                                      Text(
                                          'Cannot select past dates for bookings'),
                                    ],
                                  ),
                                  backgroundColor: Colors.red.shade600,
                                  duration: Duration(seconds: 2),
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              );
                              return;
                            }

                            setState(() {
                              _selectedDay = selected;
                              _focusedDay = focused;
                            });
                            _openAvailabilityPopup(context, selected, provider);
                          },
                          headerStyle: HeaderStyle(
                            formatButtonVisible: false,
                            titleCentered: true,
                            titleTextStyle: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Colors.red.shade700,
                            ),
                            leftChevronIcon: Icon(
                              Icons.chevron_left,
                              color: Colors.red.shade400,
                              size: 28,
                            ),
                            rightChevronIcon: Icon(
                              Icons.chevron_right,
                              color: Colors.red.shade400,
                              size: 28,
                            ),
                            formatButtonShowsNext: false,
                            formatButtonDecoration: BoxDecoration(
                              color: Colors.red.shade400,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            formatButtonTextStyle: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          calendarStyle: CalendarStyle(
                            outsideDaysVisible: false,
                            weekendTextStyle:
                                TextStyle(color: Colors.red.shade700),
                            holidayTextStyle:
                                TextStyle(color: Colors.red.shade700),
                            defaultTextStyle: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                            selectedTextStyle: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                            todayTextStyle: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                            todayDecoration: BoxDecoration(
                              color: Colors.red.shade400,
                              shape: BoxShape.circle,
                            ),
                            selectedDecoration: BoxDecoration(
                              color: Colors.red.shade600,
                              shape: BoxShape.circle,
                            ),
                          ),
                          calendarBuilders: CalendarBuilders(
                            defaultBuilder: (context, day, _) {
                              final today = DateTime.now();
                              final todayStart =
                                  DateTime(today.year, today.month, today.day);
                              final dayStart =
                                  DateTime(day.year, day.month, day.day);
                              final isPastDate = dayStart.isBefore(todayStart);

                              final color = isPastDate
                                  ? Colors.grey
                                  : _getDayBookingColor(provider, day);

                              return Container(
                                margin: EdgeInsets.all(2),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: color,
                                    width: 2,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                  color:
                                      isPastDate ? Colors.grey.shade200 : null,
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  '${day.day}',
                                  style: TextStyle(
                                    color: isPastDate
                                        ? Colors.grey.shade600
                                        : null,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
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

  Widget _buildLegend() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Availability Legend',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade700,
          ),
        ),
        SizedBox(height: 8),
        Row(
          children: [
            _buildLegendItem('Available', Colors.green, Icons.check_circle),
            SizedBox(width: 16),
            _buildLegendItem('Partially Booked', Colors.orange, Icons.warning),
            SizedBox(width: 16),
            _buildLegendItem('Fully Booked', Colors.red, Icons.block),
          ],
        ),
      ],
    );
  }

  Widget _buildLegendItem(String label, Color color, IconData icon) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Icon(
            icon,
            size: 12,
            color: Colors.white,
          ),
        ),
        SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
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

  void _openAvailabilityPopup(
      BuildContext context, DateTime date, BanquetProvider provider) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
              offset: Offset(0, -5),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.event_available, color: Colors.red.shade400),
                      SizedBox(width: 8),
                      Text(
                        'Availability for ${_formatDate(date)}',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.red.shade600,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  ...provider.halls.map((hall) {
                    final slots = provider.getSlotsForHall(hall.name);
                    return Container(
                      margin: EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: ExpansionTile(
                        title: Row(
                          children: [
                            Icon(Icons.meeting_room,
                                color: Colors.red.shade400),
                            SizedBox(width: 8),
                            Text(
                              hall.name,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.red.shade700,
                              ),
                            ),
                          ],
                        ),
                        children: slots.map((slot) {
                          final booked = provider.isSlotBooked(
                              date, hall.name, slot.label);
                          final hasDraft = provider.hasDraftBookings(
                              date, hall.name, slot.label);

                          return Container(
                            margin: EdgeInsets.symmetric(
                                horizontal: 16, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: booked
                                    ? Colors.red.shade200
                                    : hasDraft
                                        ? Colors.orange.shade200
                                        : Colors.green.shade200,
                              ),
                            ),
                            child: ListTile(
                              leading: Icon(
                                booked
                                    ? Icons.block
                                    : hasDraft
                                        ? Icons.warning
                                        : Icons.check_circle,
                                color: booked
                                    ? Colors.red.shade400
                                    : hasDraft
                                        ? Colors.orange.shade400
                                        : Colors.green.shade400,
                              ),
                              title: Text(
                                slot.label,
                                style: TextStyle(
                                  fontWeight: FontWeight.w500,
                                  color: booked
                                      ? Colors.grey.shade600
                                      : Colors.grey.shade800,
                                ),
                              ),
                              subtitle: hasDraft && !booked
                                  ? Text(
                                      'Has draft booking - can still be confirmed',
                                      style: TextStyle(
                                        color: Colors.orange.shade600,
                                        fontSize: 12,
                                        fontStyle: FontStyle.italic,
                                      ),
                                    )
                                  : null,
                              trailing: booked
                                  ? Container(
                                      padding: EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: Colors.red.shade100,
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: Text(
                                        'Booked',
                                        style: TextStyle(
                                          color: Colors.red.shade700,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    )
                                  : ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.red.shade400,
                                        foregroundColor: Colors.white,
                                        elevation: 0,
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        padding: EdgeInsets.symmetric(
                                            horizontal: 16, vertical: 8),
                                      ),
                                      child: Text(
                                        'Select',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      onPressed: () {
                                        Navigator.pop(context); // close popup

                                        if (widget.isSelectionMode) {
                                          // Return selection data to parent
                                          Navigator.pop(context, {
                                            'date': date,
                                            'hallName': hall.name,
                                            'slotLabel': slot.label,
                                            'branchId': _selectedBranchId!,
                                          });
                                        } else {
                                          // Open new booking page (original behavior)
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) =>
                                                  ChangeNotifierProvider.value(
                                                value: provider,
                                                child: BookingPage(
                                                  date: date,
                                                  hallName: hall.name,
                                                  slotLabel: slot.label,
                                                  branchId: _selectedBranchId!,
                                                ),
                                              ),
                                            ),
                                          );
                                        }
                                      },
                                    ),
                            ),
                          );
                        }).toList(),
                      ),
                    );
                  }).toList(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December'
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  // Returns green if all slots free, yellow if some booked or has drafts, red if all booked
  Color _getDayBookingColor(BanquetProvider provider, DateTime date) {
    int totalSlots = 0;
    int bookedSlots = 0;
    int draftSlots = 0;

    for (var hall in provider.halls) {
      final slots = provider.getSlotsForHall(hall.name);
      totalSlots += slots.length;
      for (var slot in slots) {
        if (provider.isSlotBooked(date, hall.name, slot.label)) {
          bookedSlots++;
        } else if (provider.hasDraftBookings(date, hall.name, slot.label)) {
          draftSlots++;
        }
      }
    }

    if (totalSlots == 0) return Colors.green; // No slots defined
    if (bookedSlots == 0 && draftSlots == 0) return Colors.green; // All free
    if (bookedSlots == totalSlots) return Colors.red; // All booked
    if (bookedSlots > 0 || draftSlots > 0)
      return Colors.orange; // Some booked or has drafts
    return Colors.green;
  }
}
