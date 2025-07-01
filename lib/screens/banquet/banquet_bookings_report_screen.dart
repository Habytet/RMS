import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:token_manager/screens/notification_screen/notification_bloc.dart';

import '../../models/banquet_booking.dart';
import '../../providers/user_provider.dart';
import 'edit_booking_page.dart';

class BanquetBookingsReportScreen extends StatefulWidget {
  BanquetBookingsReportScreen({this.notificationBloc});
  final NotificationBloc? notificationBloc;
  @override
  State<BanquetBookingsReportScreen> createState() =>
      _BanquetBookingsReportScreenState();
}

class _BanquetBookingsReportScreenState
    extends State<BanquetBookingsReportScreen> {
  String? _selectedBranchId;
  DateTimeRange? _dateRange;

  @override
  void initState() {
    super.initState();
    final userProvider = context.read<UserProvider>();
    final isCorporate = userProvider.currentUser?.branchId == 'all';
    final branches = userProvider.branches;
    if (isCorporate && branches.isNotEmpty) {
      final firstBranch = branches.firstWhere((b) => b.id != 'all',
          orElse: () => branches.first);
      _selectedBranchId = firstBranch.id;
    } else {
      _selectedBranchId = userProvider.currentBranchId;
    }
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 2),
      initialDateRange: _dateRange,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Colors.red.shade400,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.red.shade700,
              secondary: Colors.red.shade300,
              onSecondary: Colors.white,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: Colors.red.shade600,
              ),
            ),
            dialogTheme: DialogTheme(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              backgroundColor: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _dateRange = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = context.watch<UserProvider>();
    final isCorporate = userProvider.currentUser?.branchId == 'all';
    final branches = userProvider.branches;

    final bookingsStream = _selectedBranchId == null
        ? null
        : FirebaseFirestore.instance
            .collection('branches')
            .doc(_selectedBranchId)
            .collection('banquetBookings')
            .snapshots();

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text('View Bookings'),
          backgroundColor: Colors.red.shade300,
          foregroundColor: Colors.white,
          elevation: 0,
          bottom: TabBar(
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            tabs: [
              Tab(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.edit_note, size: 18),
                    SizedBox(width: 8),
                    Text('Drafts'),
                  ],
                ),
              ),
              Tab(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.event, size: 18),
                    SizedBox(width: 8),
                    Text('Upcoming'),
                  ],
                ),
              ),
            ],
          ),
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
              // Branch Selection (for corporate users)
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
                  child: DropdownButtonFormField<String>(
                    value: _selectedBranchId,
                    decoration: InputDecoration(
                      labelText: 'Select Branch',
                      labelStyle: TextStyle(color: Colors.red.shade400),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.red.shade200),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.red.shade200),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide:
                            BorderSide(color: Colors.red.shade400, width: 2),
                      ),
                      filled: true,
                      fillColor: Colors.red.shade50,
                    ),
                    items: branches
                        .where((b) => b.id != 'all')
                        .map((b) => DropdownMenuItem(
                              value: b.id,
                              child: Text(b.name),
                            ))
                        .toList(),
                    onChanged: (value) {
                      if (value != null && value != _selectedBranchId) {
                        setState(() {
                          _selectedBranchId = value;
                        });
                      }
                    },
                  ),
                ),

              // Date Range Selection
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
                child: Row(
                  children: [
                    Text(
                      'Date Range',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.red.shade600,
                      ),
                    ),
                    Spacer(),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        onPressed: _pickDateRange,
                        icon: Icon(Icons.calendar_today,
                            size: 18, color: Colors.red.shade600),
                        label: Text(
                          _dateRange == null
                              ? 'Pick Date Range'
                              : '${DateFormat('MMM dd').format(_dateRange!.start)} - ${DateFormat('MMM dd').format(_dateRange!.end)}',
                          style: TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w500),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade100,
                          foregroundColor: Colors.red.shade700,
                          padding: EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: 16),

              // Bookings List
              Expanded(
                child: bookingsStream == null
                    ? _buildEmptyState(
                        icon: Icons.business,
                        title: 'No Branch Selected',
                        subtitle: 'Please select a branch to view bookings',
                      )
                    : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                        stream: bookingsStream,
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return Center(
                              child: CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.red.shade400,
                                ),
                              ),
                            );
                          }
                          if (!snapshot.hasData ||
                              snapshot.data!.docs.isEmpty) {
                            return _buildEmptyState(
                              icon: Icons.event_busy,
                              title: 'No Bookings Found',
                              subtitle:
                                  'No bookings available for the selected criteria',
                            );
                          }

                          if (_dateRange == null) {
                            return _buildEmptyState(
                              icon: Icons.date_range,
                              title: 'Select Date Range',
                              subtitle:
                                  'Please select a date range to view bookings',
                            );
                          }

                          final docs = snapshot.data!.docs;
                          final entries = docs
                              .map((doc) => MapEntry(
                                  doc.id, BanquetBooking.fromMap(doc.data())))
                              .where((entry) {
                            final d = entry.value.date;
                            final from = DateTime(_dateRange!.start.year,
                                _dateRange!.start.month, _dateRange!.start.day);
                            final to = DateTime(
                                _dateRange!.end.year,
                                _dateRange!.end.month,
                                _dateRange!.end.day,
                                23,
                                59,
                                59);
                            return !d.isBefore(from) && !d.isAfter(to);
                          }).toList();

                          final drafts =
                              entries.where((e) => e.value.isDraft).toList();
                          final confirmed =
                              entries.where((e) => !e.value.isDraft).toList();

                          return TabBarView(
                            children: [
                              _buildList(context, drafts, 'Drafts'),
                              _buildList(context, confirmed, 'Upcoming'),
                            ],
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 48,
              color: Colors.red.shade400,
            ),
          ),
          SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade700,
            ),
          ),
          SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildList(BuildContext context,
      List<MapEntry<String, BanquetBooking>> list, String type) {
    if (list.isEmpty) {
      return _buildEmptyState(
        icon: type == 'Drafts' ? Icons.edit_note : Icons.event,
        title: 'No ${type} Bookings',
        subtitle:
            'No ${type.toLowerCase()} bookings found for the selected date range',
      );
    }

    return ListView.builder(
      padding: EdgeInsets.symmetric(horizontal: 16),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final entry = list[index];
        final booking = entry.value;
        final docId = entry.key;

        return Container(
          margin: EdgeInsets.only(bottom: 12),
          child: Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header with date and status
                  Row(
                    children: [
                      Container(
                        padding:
                            EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: type == 'Drafts'
                              ? Colors.orange.shade100
                              : Colors.green.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          DateFormat('MMM dd, yyyy').format(booking.date),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: type == 'Drafts'
                                ? Colors.orange.shade800
                                : Colors.green.shade800,
                          ),
                        ),
                      ),
                      Spacer(),
                      Container(
                        padding:
                            EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: type == 'Drafts'
                              ? Colors.orange.shade100
                              : Colors.red.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          type,
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            color: type == 'Drafts'
                                ? Colors.orange.shade800
                                : Colors.red.shade800,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: 12),

                  // Hall and Slot
                  Row(
                    children: [
                      Icon(Icons.room, color: Colors.grey.shade600, size: 20),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Hall: ${booking.hallSlots.map((hs) => hs['hallName']).join(', ')}',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: 4),

                  Row(
                    children: [
                      Icon(Icons.access_time,
                          color: Colors.grey.shade600, size: 20),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Slot: ${booking.hallSlots.map((hs) => hs['slotLabel']).join(', ')}',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: 8),

                  // PAX and Customer
                  Row(
                    children: [
                      Icon(Icons.people, color: Colors.grey.shade600, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'PAX: ${booking.pax}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Spacer(),
                      Icon(Icons.person, color: Colors.grey.shade600, size: 20),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          booking.customerName,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: 16),

                  // Edit button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => EditBookingPage(
                                booking: booking,
                                docId: docId,
                                branchId: _selectedBranchId!,
                                notificationBloc: widget.notificationBloc,
                              ),
                            ),
                          );
                        },
                        //  icon: Icon(Icons.edit, size: 18),
                        label: Text('Edit Booking'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade400,
                          foregroundColor: Colors.white,
                          padding:
                              EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
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
      },
    );
  }
}
