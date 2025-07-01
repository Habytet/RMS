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
          title: Text('Banquet Bookings'),
          bottom: TabBar(
            tabs: [
              Tab(text: 'Drafts'),
              Tab(text: 'Upcoming'),
            ],
          ),
        ),
        body: Column(
          children: [
            if (isCorporate)
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: DropdownButtonFormField<String>(
                  value: _selectedBranchId,
                  decoration: const InputDecoration(
                    labelText: 'Select Branch',
                    border: OutlineInputBorder(),
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
            Expanded(
              child: bookingsStream == null
                  ? Center(child: Text('No branch selected'))
                  : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: bookingsStream,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return Center(child: CircularProgressIndicator());
                        }
                        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                          return Center(child: Text('No bookings found'));
                        }

                        final docs = snapshot.data!.docs;
                        final entries = docs
                            .map((doc) => MapEntry(
                                doc.id, BanquetBooking.fromJson(doc.data())))
                            .toList();

                        final drafts =
                            entries.where((e) => e.value.isDraft).toList();
                        final confirmed =
                            entries.where((e) => !e.value.isDraft).toList();

                        return TabBarView(
                          children: [
                            _buildList(context, drafts),
                            _buildList(context, confirmed),
                          ],
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList(
      BuildContext context, List<MapEntry<String, BanquetBooking>> list) {
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
            title: Text(
                '${booking.hallInfos.first.name} • ${booking.hallInfos.first.slots.first.label}'),
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
                      branchId: _selectedBranchId!,
                      notificationBloc: widget.notificationBloc,
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
