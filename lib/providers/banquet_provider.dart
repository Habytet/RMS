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

    // Always start listening for data, but handle 'all' branch differently
    _init();
  }

  void _init() {
    print('DEBUG: BanquetProvider._init() called for branchId: $branchId');

    // These listeners will now only get data for the specified branch
    _hallCol.snapshots().listen((snapshot) {
      halls = snapshot.docs
          .map((doc) => Hall.fromMap(doc.data() as Map<String, dynamic>))
          .toList();
      print('DEBUG: Loaded ${halls.length} halls for branch $branchId');
      notifyListeners();
    });

    _slotCol.snapshots().listen((snapshot) {
      slots = snapshot.docs
          .map((doc) => Slot.fromMap(doc.data() as Map<String, dynamic>))
          .toList();
      print('DEBUG: Loaded ${slots.length} slots for branch $branchId');
      notifyListeners();
    });

    _bookingCol.snapshots().listen((snapshot) {
      bookings = snapshot.docs
          .map((doc) =>
              BanquetBooking.fromMap(doc.data() as Map<String, dynamic>))
          .toList();
      print('DEBUG: Loaded ${bookings.length} bookings for branch $branchId');
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
    final dayOnly = DateTime(date.year, date.month, date.day);

    print(
        'DEBUG: isSlotBooked checking for date: $dayOnly, hall: $hallName, slot: $slotLabel');
    print('DEBUG: Total bookings to check: ${bookings.length}');

    final isBooked = bookings.any((b) {
      // Skip draft bookings - they don't block slots
      if (b.isDraft) {
        print('DEBUG: Skipping draft booking ${b.customerName}');
        return false;
      }

      final bd = b.date;
      final bdDay = DateTime(bd.year, bd.month, bd.day);
      final containsSlot = b.containsHallSlot(hallName, slotLabel);

      print(
          'DEBUG: Checking booking ${b.customerName} - date: $bdDay, containsSlot: $containsSlot, isDraft: ${b.isDraft}');

      return bdDay == dayOnly && containsSlot;
    });

    print('DEBUG: isSlotBooked($date, $hallName, $slotLabel) = $isBooked');
    print('DEBUG: Total bookings for this check: ${bookings.length}');

    return isBooked;
  }

  /// Check if multiple halls are available for a given date and slot
  List<String> getAvailableHalls(DateTime date, String slotLabel) {
    final dayOnly = DateTime(date.year, date.month, date.day);

    // Get all halls in this branch
    List<String> allHalls = halls.map((h) => h.name).toList();

    // Get booked halls for this date and slot (excluding drafts)
    Set<String> bookedHalls = {};
    for (var booking in bookings) {
      // Skip draft bookings - they don't block halls
      if (booking.isDraft) continue;

      final bd = booking.date;
      final bdDay = DateTime(bd.year, bd.month, bd.day);
      if (bdDay == dayOnly && booking.containsHallSlot('', slotLabel)) {
        // Find which halls are booked for this slot
        for (var hallSlot in booking.hallSlots) {
          if (hallSlot['slotLabel'] == slotLabel) {
            bookedHalls.add(hallSlot['hallName'] ?? '');
          }
        }
      }
    }

    // Return available halls
    return allHalls.where((hall) => !bookedHalls.contains(hall)).toList();
  }

  /// Check if specific halls are available for a given date and slot
  bool areHallsAvailable(
      DateTime date, String slotLabel, List<String> hallNames) {
    final availableHalls = getAvailableHalls(date, slotLabel);
    return hallNames.every((hall) => availableHalls.contains(hall));
  }

  /// Get all available hall+slot combinations for a given date
  List<Map<String, String>> getAvailableHallSlots(DateTime date) {
    final dayOnly = DateTime(date.year, date.month, date.day);
    List<Map<String, String>> availableCombinations = [];

    // Get all halls and their slots
    for (var hall in halls) {
      final slots = getSlotsForHall(hall.name);

      for (var slot in slots) {
        // Check if this hall+slot combination is available (excluding drafts)
        bool isBooked = bookings.any((b) {
          // Skip draft bookings - they don't block slots
          if (b.isDraft) return false;

          final bd = b.date;
          final bdDay = DateTime(bd.year, bd.month, bd.day);
          return bdDay == dayOnly && b.containsHallSlot(hall.name, slot.label);
        });

        if (!isBooked) {
          availableCombinations.add({
            'hallName': hall.name,
            'slotLabel': slot.label,
          });
        }
      }
    }

    return availableCombinations;
  }

  /// Check if specific hall+slot combinations are available
  bool areHallSlotsAvailable(
      DateTime date, List<Map<String, String>> hallSlots) {
    final dayOnly = DateTime(date.year, date.month, date.day);

    for (var hallSlot in hallSlots) {
      final hallName = hallSlot['hallName'] ?? '';
      final slotLabel = hallSlot['slotLabel'] ?? '';

      bool isBooked = bookings.any((b) {
        // Skip draft bookings - they don't block slots
        if (b.isDraft) return false;

        final bd = b.date;
        final bdDay = DateTime(bd.year, bd.month, bd.day);
        return bdDay == dayOnly && b.containsHallSlot(hallName, slotLabel);
      });

      if (isBooked) return false;
    }

    return true;
  }

  Future<String?> createBooking(BanquetBooking booking) async {
    try {
      print('DEBUG: Creating booking for date: ${booking.date}');
      print('DEBUG: Hall slots: ${booking.hallSlots}');
      print('DEBUG: Customer: ${booking.customerName}');
      print('DEBUG: Is draft: ${booking.isDraft}');
      print(
          'DEBUG: Current bookings count before creation: ${bookings.length}');

      final docRef = await _bookingCol.add(booking.toMap());
      print('DEBUG: Booking created successfully with ID: ${docRef.id}');

      // Wait a moment for the Firestore listener to pick up the change
      await Future.delayed(Duration(milliseconds: 500));

      print('DEBUG: Current bookings count after creation: ${bookings.length}');
      print(
          'DEBUG: All bookings after creation: ${bookings.map((b) => '${b.customerName} - ${b.hallSlots}').toList()}');

      return docRef.id;
    } catch (e) {
      print('ERROR: Failed to create booking: $e');
      return null;
    }
  }

  Future<void> updateBooking(String docId, BanquetBooking booking) async {
    try {
      print('DEBUG: Updating booking with ID: $docId');
      print(
          'DEBUG: New booking data - date: ${booking.date}, customer: ${booking.customerName}');
      print('DEBUG: New hall slots: ${booking.hallSlots}');
      print('DEBUG: Is draft: ${booking.isDraft}');

      await _bookingCol.doc(docId).update(booking.toMap());

      print('DEBUG: Booking updated successfully');
    } catch (e) {
      print('ERROR: Failed to update booking: $e');
      rethrow;
    }
  }

  /// Get all available hall+slot combinations for a given date, excluding already selected ones
  List<Map<String, String>> getAvailableHallSlotsExcluding(
      DateTime date, List<Map<String, String>> excludeHallSlots) {
    final allAvailable = getAvailableHallSlots(date);

    // Filter out the ones that are already selected
    return allAvailable.where((hallSlot) {
      return !excludeHallSlots.any((exclude) =>
          exclude['hallName'] == hallSlot['hallName'] &&
          exclude['slotLabel'] == hallSlot['slotLabel']);
    }).toList();
  }

  /// Check if a slot has draft bookings (for visual indication only)
  bool hasDraftBookings(DateTime date, String hallName, String slotLabel) {
    final dayOnly = DateTime(date.year, date.month, date.day);

    return bookings.any((b) {
      // Only check draft bookings
      if (!b.isDraft) {
        return false;
      }

      final bd = b.date;
      final bdDay = DateTime(bd.year, bd.month, bd.day);
      final containsSlot = b.containsHallSlot(hallName, slotLabel);

      return bdDay == dayOnly && containsSlot;
    });
  }

  /// Get filtered bookings stream for chef display
  Stream<List<BanquetBooking>> getBookingsStream({
    DateTime? fromDate,
    DateTime? toDate,
    String? status,
  }) {
    return _bookingCol.snapshots().map((snapshot) {
      List<BanquetBooking> filteredBookings = snapshot.docs
          .map((doc) =>
              BanquetBooking.fromMap(doc.data() as Map<String, dynamic>))
          .where((booking) {
        // Filter by date range
        if (fromDate != null) {
          final bookingDate =
              DateTime(booking.date.year, booking.date.month, booking.date.day);
          final fromDateOnly =
              DateTime(fromDate.year, fromDate.month, fromDate.day);
          if (bookingDate.isBefore(fromDateOnly)) return false;
        }

        if (toDate != null) {
          final bookingDate =
              DateTime(booking.date.year, booking.date.month, booking.date.day);
          final toDateOnly = DateTime(toDate.year, toDate.month, toDate.day);
          if (bookingDate.isAfter(toDateOnly)) return false;
        }

        // Filter by status
        if (status == 'upcoming') {
          return !booking.isDraft; // Upcoming = not draft
        } else if (status == 'draft') {
          return booking.isDraft; // Draft = is draft
        }

        return true; // No status filter
      }).toList();

      return filteredBookings;
    });
  }
}
