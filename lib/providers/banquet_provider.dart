import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/hall.dart';
import '../models/slot.dart';
import '../models/banquet_booking.dart';

class BanquetProvider extends ChangeNotifier {
  final _hallCol = FirebaseFirestore.instance.collection('halls');
  final _slotCol = FirebaseFirestore.instance.collection('slots');
  final _bookingCol = FirebaseFirestore.instance.collection('banquetBookings');

  List<Hall> halls = [];
  List<Slot> slots = [];
  List<BanquetBooking> bookings = [];

  BanquetProvider() {
    _init();
  }

  void _init() {
    _hallCol.snapshots().listen((snapshot) {
      halls = snapshot.docs.map((doc) => Hall.fromMap(doc.data())).toList();
      notifyListeners();
    });

    _slotCol.snapshots().listen((snapshot) {
      slots = snapshot.docs.map((doc) => Slot.fromMap(doc.data())).toList();
      notifyListeners();
    });

    _bookingCol.snapshots().listen((snapshot) {
      bookings = snapshot.docs.map((doc) => BanquetBooking.fromMap(doc.data())).toList();
      notifyListeners();
    });
  }

  Future<void> addHall(String name) async {
    final hall = Hall(name: name);
    await _hallCol.doc(name).set(hall.toMap());
  }

  Future<void> removeHall(String name) async {
    await _hallCol.doc(name).delete();
    final relatedSlots = await _slotCol.where('hallName', isEqualTo: name).get();
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
      return bdDay == DateTime(date.year, date.month, date.day) &&
          b.hallName == hallName &&
          b.slotLabel == slotLabel;
    });
  }

  Future<void> createBooking(BanquetBooking booking) async {
    await _bookingCol.add(booking.toMap());
  }

  Future<void> updateBooking(String docId, BanquetBooking booking) async {
    await _bookingCol.doc(docId).update(booking.toMap());
  }
}
