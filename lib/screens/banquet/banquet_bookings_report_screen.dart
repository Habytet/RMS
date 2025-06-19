import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';

import '../../models/banquet_booking.dart';
import 'edit_booking_page.dart';

class BanquetBookingsReportScreen extends StatefulWidget {
  @override
  State<BanquetBookingsReportScreen> createState() => _BanquetBookingsReportScreenState();
}

class _BanquetBookingsReportScreenState extends State<BanquetBookingsReportScreen> {
  List<BanquetBooking> drafts = [];
  List<BanquetBooking> confirmed = [];

  @override
  void initState() {
    super.initState();
    _loadBookings();
  }

  void _loadBookings() {
    final bookings = Hive.box<BanquetBooking>('banquetBookings').values.toList();
    setState(() {
      drafts = bookings.where((b) => b.isDraft).toList();
      confirmed = bookings.where((b) => !b.isDraft).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text('Banquet Bookings'),
          bottom: TabBar(tabs: [
            Tab(text: 'Drafts (${drafts.length})'),
            Tab(text: 'Upcoming (${confirmed.length})'),
          ]),
        ),
        body: TabBarView(
          children: [
            _buildListView(drafts),
            _buildListView(confirmed),
          ],
        ),
      ),
    );
  }

  Widget _buildListView(List<BanquetBooking> list) {
    if (list.isEmpty) {
      return Center(child: Text('No bookings found'));
    }

    return ListView.builder(
      itemCount: list.length,
      itemBuilder: (context, index) {
        final booking = list[index];
        return Card(
          margin: const EdgeInsets.all(10),
          elevation: 3,
          child: ListTile(
            title: Text('${booking.hallName} • ${booking.slotLabel}'),
            subtitle: Text('Date: ${DateFormat('yyyy-MM-dd').format(booking.date)} — Pax: ${booking.pax}'),
            trailing: Icon(Icons.arrow_forward_ios),
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => EditBookingPage(booking: booking),
                ),
              );
              _loadBookings();
            },
          ),
        );
      },
    );
  }
}