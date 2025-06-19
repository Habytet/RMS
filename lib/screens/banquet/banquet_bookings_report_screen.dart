import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../models/banquet_booking.dart';
import '../../providers/user_provider.dart';
import 'edit_booking_page.dart';

class BanquetBookingsReportScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final branchId = context.read<UserProvider>().currentBranchId;
    final bookingsStream = FirebaseFirestore.instance
        .collection('branches/$branchId/banquetBookings')
        .snapshots();

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text('Banquet Bookings'),
          bottom: TabBar(
            tabs: [
              Tab(text: 'Drafts'),
              Tab(text: 'Upcoming'),
            ],
          ),
        ),
        body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: bookingsStream,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(child: CircularProgressIndicator());
            }
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return Center(child: Text('No bookings found'));
            }

            final docs = snapshot.data!.docs;
            final entries = docs
                .map((doc) => MapEntry(doc.id, BanquetBooking.fromMap(doc.data())))
                .toList();

            final drafts = entries.where((e) => e.value.isDraft).toList();
            final confirmed = entries.where((e) => !e.value.isDraft).toList();

            return TabBarView(
              children: [
                _buildList(context, drafts),
                _buildList(context, confirmed),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildList(BuildContext context, List<MapEntry<String, BanquetBooking>> list) {
    if (list.isEmpty) {
      return Center(child: Text('No bookings found'));
    }
    return ListView.builder(
      itemCount: list.length,
      itemBuilder: (context, index) {
        final entry = list[index];
        final booking = entry.value;
        final docId = entry.key;
        return Card(
          margin: const EdgeInsets.all(10),
          elevation: 3,
          child: ListTile(
            title: Text('${booking.hallName} • ${booking.slotLabel}'),
            subtitle: Text(
              'Date: ${DateFormat('yyyy-MM-dd').format(booking.date)} — Pax: ${booking.pax}',
            ),
            trailing: IconButton(
              icon: Icon(Icons.edit),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => EditBookingPage(
                      booking: booking,
                      docId: docId,
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}
