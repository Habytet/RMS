import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/banquet_booking.dart';
import '../../providers/banquet_provider.dart';
import '../../providers/user_provider.dart';
import 'chef_booking_detail_screen.dart';

class ChefDisplayScreen extends StatefulWidget {
  @override
  _ChefDisplayScreenState createState() => _ChefDisplayScreenState();
}

class _ChefDisplayScreenState extends State<ChefDisplayScreen> {
  DateTime _fromDate = DateTime.now();
  DateTime _toDate = DateTime.now().add(Duration(days: 7));
  String? _selectedBranchId;

  @override
  void initState() {
    super.initState();
    final userProvider = context.read<UserProvider>();
    final user = userProvider.currentUser;
    if (user != null && user.isAdmin) {
      // Default to first branch if admin
      final branches = userProvider.branches;
      if (branches.isNotEmpty) {
        _selectedBranchId = branches.first.id;
      }
    } else {
      _selectedBranchId = user?.branchId;
    }
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = context.watch<UserProvider>();
    final user = userProvider.currentUser;
    final branches = userProvider.branches;

    // Ensure we have a valid branch ID
    if (_selectedBranchId == null && branches.isNotEmpty) {
      _selectedBranchId = branches.first.id;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Chef Display'),
        backgroundColor: Colors.red.shade300,
      ),
      body: Column(
        children: [
          if (user != null && user.isAdmin)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: DropdownButtonFormField<String>(
                value: _selectedBranchId,
                decoration: InputDecoration(
                  labelText: 'Select Branch',
                  border: OutlineInputBorder(),
                ),
                items: branches
                    .map((b) => DropdownMenuItem(
                          value: b.id,
                          child: Text(b.name),
                        ))
                    .toList(),
                onChanged: (val) {
                  setState(() {
                    _selectedBranchId = val;
                  });
                },
              ),
            ),
          Expanded(
            child: _selectedBranchId == null
                ? Center(
                    child: Text(
                        'Unable to determine branch. Please contact administrator.'),
                  )
                : ChangeNotifierProvider<BanquetProvider>(
                    key: ValueKey(_selectedBranchId),
                    create: (_) =>
                        BanquetProvider(branchId: _selectedBranchId!),
                    child: Consumer<BanquetProvider>(
                      builder: (context, banquetProvider, _) {
                        return StreamBuilder<List<BanquetBooking>>(
                          stream: banquetProvider.getBookingsStream(
                            fromDate: _fromDate,
                            toDate: _toDate,
                            status: 'upcoming', // Only upcoming bookings
                          ),
                          builder: (context, snapshot) {
                            if (snapshot.hasError) {
                              return Center(
                                child: Text(
                                    'Error loading bookings: ${snapshot.error}'),
                              );
                            }

                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return Center(child: CircularProgressIndicator());
                            }

                            final bookings = snapshot.data ?? [];

                            if (bookings.isEmpty) {
                              return Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.restaurant_menu,
                                      size: 64,
                                      color: Colors.grey.shade400,
                                    ),
                                    SizedBox(height: 16),
                                    Text(
                                      'No upcoming bookings for the next 7 days',
                                      style: TextStyle(
                                        fontSize: 18,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                    SizedBox(height: 8),
                                    Text(
                                      'Date range: ${DateFormat('MMM dd').format(_fromDate)} - ${DateFormat('MMM dd').format(_toDate)}',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey.shade500,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }

                            return Column(
                              children: [
                                // Date range header
                                Container(
                                  width: double.infinity,
                                  padding: EdgeInsets.all(16),
                                  color: Colors.red.shade50,
                                  child: Row(
                                    children: [
                                      Icon(Icons.calendar_today,
                                          color: Colors.red.shade400),
                                      SizedBox(width: 8),
                                      Text(
                                        'Upcoming Bookings: ${DateFormat('MMM dd').format(_fromDate)} - ${DateFormat('MMM dd').format(_toDate)}',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.red.shade600,
                                        ),
                                      ),
                                      Spacer(),
                                      Text(
                                        '${bookings.length} booking${bookings.length == 1 ? '' : 's'}',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.red.shade400,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                // Bookings list
                                Expanded(
                                  child: ListView.builder(
                                    padding: EdgeInsets.all(16),
                                    itemCount: bookings.length,
                                    itemBuilder: (context, index) {
                                      final booking = bookings[index];
                                      return _buildBookingCard(booking);
                                    },
                                  ),
                                ),
                              ],
                            );
                          },
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildBookingCard(BanquetBooking booking) {
    return Card(
      margin: EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with date and status
            Row(
              children: [
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    DateFormat('MMM dd, yyyy').format(booking.date),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade800,
                    ),
                  ),
                ),
                Spacer(),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Upcoming',
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: Colors.blue.shade800,
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
                Text(
                  'Hall: ${booking.hallSlots.map((hs) => hs['hallName']).join(', ')}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),

            SizedBox(height: 4),

            Row(
              children: [
                Icon(Icons.access_time, color: Colors.grey.shade600, size: 20),
                SizedBox(width: 8),
                Text(
                  'Slot: ${booking.hallSlots.map((hs) => hs['slotLabel']).join(', ')}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),

            SizedBox(height: 8),

            // PAX
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
              ],
            ),

            SizedBox(height: 8),

            // Customer name
            Row(
              children: [
                Icon(Icons.person, color: Colors.grey.shade600, size: 20),
                SizedBox(width: 8),
                Text(
                  'Customer: ${booking.customerName}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),

            // Menu preview (if available)
            if (booking.menu.isNotEmpty) ...[
              SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.restaurant_menu,
                      color: Colors.grey.shade600, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Menu: ${booking.menu.split('\n').first}', // Show first line of menu
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade700,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],

            SizedBox(height: 16),

            // View button
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            ChefBookingDetailScreen(booking: booking),
                      ),
                    );
                  },
                  // icon: Icon(Icons.visibility, size: 18),
                  label: Text('View Details'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade400,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
