import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import '../models/hall.dart';
import '../models/slot.dart';
import '../models/banquet_booking.dart';

class BanquetProvider extends ChangeNotifier {
  final _hallBox = Hive.box<Hall>('halls');
  final _slotBox = Hive.box<Slot>('slots');
  final _bookingBox = Hive.box<BanquetBooking>('banquetBookings');

  List<Hall> get halls => _hallBox.values.toList();
  List<Slot> get slots => _slotBox.values.toList();
  List<BanquetBooking> get bookings => _bookingBox.values.toList();

  void addHall(String name) {
    final hall = Hall(name: name);
    _hallBox.put(name, hall);
    notifyListeners();
  }

  void removeHall(String name) {
    _hallBox.delete(name);
    final relatedSlots = _slotBox.values
        .where((slot) => slot.hallName == name)
        .toList();
    for (final slot in relatedSlots) {
      _slotBox.delete(slot.key);
    }
    notifyListeners();
  }

  void addSlot(String hallName, String label) {
    final slot = Slot(hallName: hallName, label: label);
    _slotBox.add(slot);
    notifyListeners();
  }

  void removeSlot(String hallName, String label) {
    final target = _slotBox.values.cast<Slot?>().firstWhere(
          (s) => s!.hallName == hallName && s.label == label,
      orElse: () => null,
    );
    if (target != null) {
      _slotBox.delete(target.key);
      notifyListeners();
    }
  }

  List<Slot> getSlotsForHall(String hallName) {
    return _slotBox.values.where((s) => s.hallName == hallName).toList();
  }

  List<BanquetBooking> getBookingsForDate(DateTime date) {
    final dayOnly = DateTime(date.year, date.month, date.day);
    return _bookingBox.values.where((b) =>
    b.date.year == dayOnly.year &&
        b.date.month == dayOnly.month &&
        b.date.day == dayOnly.day
    ).toList();
  }

  bool isSlotBooked(DateTime date, String hallName, String slotLabel) {
    return _bookingBox.values.any((b) =>
    b.date.year == date.year &&
        b.date.month == date.month &&
        b.date.day == date.day &&
        b.hallName == hallName &&
        b.slotLabel == slotLabel
    );
  }

  void createBooking(BanquetBooking booking) {
    _bookingBox.add(booking);
    notifyListeners();
  }

  void updateBooking(BanquetBooking booking) {
    booking.save();
    notifyListeners();
  }
}