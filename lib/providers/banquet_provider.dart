// lib/providers/banquet_provider.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/hall.dart';
import '../models/slot.dart';
import '../models/banquet_booking.dart';

class BanquetProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String branchId;

  // These will now point to a specific branch's subcollection
  late final CollectionReference _hallCol;
  late final CollectionReference _slotCol;
  late final CollectionReference _bookingCol;

  List<Hall> halls = [];
  List<Slot> slots = [];
  List<BanquetBooking> bookings = [];

  // --- FIX: The constructor now accepts the branchId ---
  BanquetProvider({required this.branchId}) {
    // --- FIX: Firestore paths are now built dynamically using the branchId ---
    // This creates paths like 'branches/branch_A/halls'
    final branchDoc = _firestore.collection('branches').doc(branchId);
    _hallCol = branchDoc.collection('halls');
    _slotCol = branchDoc.collection('slots');
    _bookingCol = branchDoc.collection('banquetBookings');

    // Only start listening for data if a specific branch is selected
    if (branchId != 'all') {
      _init();
    }
  }

  void _init() {
    // These listeners will now only get data for the specified branch
    _hallCol.snapshots().listen((snapshot) {
      halls = snapshot.docs
          .map((doc) => Hall.fromMap(doc.data() as Map<String, dynamic>))
          .toList();
      notifyListeners();
    });

    _slotCol.snapshots().listen((snapshot) {
      slots = snapshot.docs
          .map((doc) => Slot.fromMap(doc.data() as Map<String, dynamic>))
          .toList();
      notifyListeners();
    });

    _bookingCol.snapshots().listen((snapshot) {
      bookings = snapshot.docs
          .map((doc) =>
              BanquetBooking.fromJson(doc.data() as Map<String, dynamic>))
          .toList();
      notifyListeners();
    });
  }

  // The rest of the functions work as before, but now they operate
  // on the branch-specific collections defined in the constructor.

  Future<void> addHall(String name) async {
    final hall = Hall(name: name);
    await _hallCol.doc(name).set(hall.toMap());
  }

  Future<void> removeHall(String name) async {
    await _hallCol.doc(name).delete();
    final relatedSlots =
        await _slotCol.where('hallName', isEqualTo: name).get();
    for (var doc in relatedSlots.docs) {
      await _slotCol.doc(doc.id).delete();
    }
  }

  Future<void> addSlot(String hallName, String label) async {
    final slot = Slot(hallName: hallName, label: label);
    await _slotCol.add(slot.toMap());
  }

  Future<void> removeSlot(String hallName, String label) async {
    final query = await _slotCol
        .where('hallName', isEqualTo: hallName)
        .where('label', isEqualTo: label)
        .get();
    for (var doc in query.docs) {
      await _slotCol.doc(doc.id).delete();
    }
  }

  List<Slot> getSlotsForHall(String hallName) {
    return slots.where((s) => s.hallName == hallName).toList();
  }

  List<BanquetBooking> getBookingsForDate(DateTime date) {
    final dayOnly = DateTime(date.year, date.month, date.day);
    return bookings.where((b) {
      final bd = b.date;
      final bdDay = DateTime(bd.year, bd.month, bd.day);
      return bdDay == dayOnly;
    }).toList();
  }

  bool isSlotBooked(DateTime date, String hallName, String slotLabel) {
    return bookings.any((b) {
      final bd = b.date;
      final bdDay = DateTime(bd.year, bd.month, bd.day);
      final isMatched = bdDay == DateTime(date.year, date.month, date.day);
      if (!isMatched) {
        return false;
      }
      for (final HallInfo info in b.hallInfos) {
        if (info.name == hallName) {
          for (final Slot slot in info.slots) {
            if (slot == slotLabel) {
              return true;
            }
          }
        }
      }
      return false;
    });
  }

  Future<void> createBooking(BanquetBooking booking) async {
    await _bookingCol.add(booking.toJson());
  }

  Future<void> updateBooking(String docId, BanquetBooking booking) async {
    await _bookingCol.doc(docId).update(booking.toJson());
  }
}
