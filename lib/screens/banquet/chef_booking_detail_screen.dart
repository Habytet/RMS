import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/banquet_booking.dart';

class ChefBookingDetailScreen extends StatelessWidget {
  final BanquetBooking booking;

  const ChefBookingDetailScreen({Key? key, required this.booking})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Booking Details'),
        backgroundColor: Colors.red.shade300,
        iconTheme: IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header card with date and status
            Card(
              color: Colors.red.shade50,
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(
                      Icons.event,
                      color: Colors.red.shade400,
                      size: 32,
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            DateFormat('EEEE, MMMM dd, yyyy')
                                .format(booking.date),
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.red.shade600,
                            ),
                          ),
                          SizedBox(height: 4),
                          Container(
                            padding: EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.green.shade100,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'Upcoming Booking',
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                                color: Colors.green.shade800,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            SizedBox(height: 16),

            // Venue Information
            _buildSectionCard(
              title: 'Venue Information',
              icon: Icons.room,
              children: [
                _buildInfoRow('Hall(s)',
                    booking.hallSlots.map((hs) => hs['hallName']).join(', ')),
                _buildInfoRow('Slot(s)',
                    booking.hallSlots.map((hs) => hs['slotLabel']).join(', ')),
              ],
            ),

            SizedBox(height: 16),

            // Customer Information
            _buildSectionCard(
              title: 'Customer Information',
              icon: Icons.person,
              children: [
                _buildInfoRow('Customer Name', booking.customerName),
                // _buildInfoRow('Phone', booking.phone),
                _buildInfoRow('PAX', '${booking.pax} people'),
              ],
            ),

            SizedBox(height: 16),

            // Menu Information
            if (booking.menu.isNotEmpty)
              _buildSectionCard(
                title: 'Menu Details',
                icon: Icons.restaurant_menu,
                children: [
                  _buildMenuItems(booking.menu),
                ],
              ),

            SizedBox(height: 16),

            // Financial Information
            // _buildSectionCard(
            //   title: 'Financial Details',
            //   icon: Icons.attach_money,
            //   children: [
            //     _buildInfoRow('Total Amount', '₹${booking.totalAmount}'),
            //     _buildInfoRow('Amount Received', '₹${booking.amount}'),
            //     _buildInfoRow(
            //         'Remaining Amount', '₹${booking.remainingAmount}'),
            //   ],
            // ),
            //
            // SizedBox(height: 16),

            // Additional Information
            if (booking.comments.isNotEmpty || booking.callbackTime != null)
              _buildSectionCard(
                title: 'Additional Information',
                icon: Icons.info,
                children: [
                  if (booking.comments.isNotEmpty)
                    _buildInfoRow('Comments', booking.comments),
                  if (booking.callbackTime != null)
                    _buildInfoRow(
                      'Callback Time',
                      DateFormat('MMM dd, yyyy - hh:mm a')
                          .format(booking.callbackTime!),
                    ),
                ],
              ),

            SizedBox(height: 24),

            // Read-only notice
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                border: Border.all(color: Colors.blue.shade200),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline,
                      color: Colors.blue.shade700, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This is a read-only view. Contact management for any changes.',
                      style: TextStyle(
                        color: Colors.blue.shade800,
                        fontSize: 14,
                      ),
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

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: Colors.red.shade400, size: 24),
                SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.red.shade600,
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItems(String menuString) {
    final menuLines = menuString.split('\n');
    final menuName = menuLines.first;
    final menuItems =
        menuLines.skip(1).where((line) => line.trim().isNotEmpty).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildInfoRow('Menu Name', menuName),
        if (menuItems.isNotEmpty) ...[
          SizedBox(height: 8),
          Text(
            'Selected Items:',
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade700,
            ),
          ),
          SizedBox(height: 4),
          ...menuItems
              .map((item) => Padding(
                    padding: EdgeInsets.only(left: 16, bottom: 4),
                    child: Row(
                      children: [
                        Icon(Icons.fiber_manual_record,
                            size: 8, color: Colors.red.shade400),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            item.trim(),
                            style: TextStyle(
                              color: Colors.black87,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ))
              .toList(),
        ],
      ],
    );
  }
}
