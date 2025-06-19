// lib/providers/user_provider.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/app_user.dart';

/// Manages user authentication via Firebase Auth and Firestore-backed profiles
class UserProvider extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  AppUser? _currentUser;
  AppUser? get currentUser => _currentUser;

  String _currentBranchId = 'all';
  String get currentBranchId => _currentBranchId;

  /// Sign in using Firebase Auth and load user profile
  Future<bool> login(String email, String password) async {
    final cred = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    final uid = cred.user!.uid;

    final doc = await _firestore.collection('users').doc(uid).get();
    if (!doc.exists) {
      throw FirebaseAuthException(
        code: 'no-profile',
        message: 'User profile not found in Firestore',
      );
    }

    final data = doc.data()!;
    _currentUser = AppUser.fromMap(data);
    _currentBranchId = data['branchId'] as String? ?? 'all';
    notifyListeners();
    return true;
  }

  /// Sign out and clear context
  Future<void> logout() async {
    await _auth.signOut();
    _currentUser = null;
    _currentBranchId = 'all';
    notifyListeners();
  }

  /// Register a new user in Firebase Auth and Firestore
  Future<void> addUser(String email, String password, AppUser profile) async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    final uid = cred.user!.uid;
    final map = profile.toMap();
    map['branchId'] = profile.branchId;
    await _firestore.collection('users').doc(uid).set(map);
  }

  /// Update an existing user profile in Firestore
  Future<void> updateUser(String uid, AppUser profile) async {
    final map = profile.toMap();
    map['branchId'] = profile.branchId;
    await _firestore.collection('users').doc(uid).update(map);
  }

  // --- NEW: Function to delete a user's profile from Firestore ---
  /// Deletes the user's document from the 'users' collection.
  /// Note: This does not delete the user from Firebase Authentication.
  Future<void> deleteUser(String uid) async {
    // Prevent a user from deleting themselves
    if (_auth.currentUser?.uid == uid) {
      throw Exception("You cannot delete your own account.");
    }
    await _firestore.collection('users').doc(uid).delete();
  }
}
