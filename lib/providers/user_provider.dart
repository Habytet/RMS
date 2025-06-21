import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart'; // Required for the fix
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/app_user.dart';
import '../models/branch.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

class UserProvider extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  AppUser? _currentUser;
  String _currentBranchId = 'all';
  List<Branch> _branches = [];
  bool _isLoadingBranches = true;
  AuthStatus _authStatus = AuthStatus.unknown;

  StreamSubscription? _branchSubscription;
  StreamSubscription? _authSubscription;

  AppUser? get currentUser => _currentUser;
  String get currentBranchId => _currentBranchId;
  List<Branch> get branches => List.unmodifiable(_branches);
  bool get isLoadingBranches => _isLoadingBranches;
  AuthStatus get authStatus => _authStatus;

  UserProvider() {
    _authSubscription = _auth.authStateChanges().listen(_onAuthStateChanged);
  }

  Future<void> _onAuthStateChanged(User? user) async {
    await _branchSubscription?.cancel();
    _branches = [];
    _isLoadingBranches = true;

    if (user == null) {
      _currentUser = null;
      _currentBranchId = 'all';
      _authStatus = AuthStatus.unauthenticated;
    } else {
      await _loadUserProfile(user);
      if (_currentUser != null) {
        _authStatus = AuthStatus.authenticated;
        _listenToBranches();
      } else {
        _authStatus = AuthStatus.unauthenticated;
        await _auth.signOut();
      }
    }
    notifyListeners();
  }

  Future<void> _loadUserProfile(User user) async {
    try {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (doc.exists && doc.data() != null) {
        _currentUser = AppUser.fromMap(doc.data()!);
        _currentBranchId = _currentUser!.branchId;
      } else {
        _currentUser = null;
      }
    } catch (e) {
      debugPrint('Error loading user profile: $e');
      _currentUser = null;
    }
  }

  void _listenToBranches() {
    _isLoadingBranches = true;
    notifyListeners();
    _branchSubscription = _firestore.collection('branches').snapshots().listen((snapshot) {
      _branches = snapshot.docs
          .map((doc) => Branch.fromFirestore(doc.id, doc.data() as Map<String, dynamic>))
          .toList();
      _isLoadingBranches = false;
      notifyListeners();
    }, onError: (error) {
      debugPrint('Error listening to branches: $error');
      _isLoadingBranches = false;
      _branches = [];
      notifyListeners();
    });
  }

  // *** CRITICAL FIX: This function no longer logs the admin out. ***
  Future<void> addUser(String email, String password, AppUser profile) async {
    // Create a temporary, secondary Firebase app instance.
    FirebaseApp tempApp = await Firebase.initializeApp(
      name: 'tempUserCreator', // A unique name for the temporary app
      options: Firebase.app().options,
    );

    try {
      // Create the user with the temporary auth instance.
      // This does NOT affect the main app's logged-in admin.
      UserCredential newUserCredential = await FirebaseAuth.instanceFor(app: tempApp)
          .createUserWithEmailAndPassword(email: email, password: password);

      // After creating the user, save their profile to Firestore using their new UID.
      await _firestore.collection('users').doc(newUserCredential.user!.uid).set(profile.toMap());
    } finally {
      // Delete the temporary app instance to clean up resources.
      await tempApp.delete();
    }
  }

  Future<void> login(String email, String password) async {
    await _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  Future<void> logout() async {
    await _auth.signOut();
  }

  Future<void> addBranch(String name) async {
    if (name.isEmpty) return;
    await _firestore.collection('branches').add({'name': name});
  }

  Future<void> updateUser(String uid, AppUser profile) async {
    await _firestore.collection('users').doc(uid).update(profile.toMap());
  }

  Future<void> deleteUser(String uid) async {
    if (_auth.currentUser?.uid == uid) {
      throw Exception('Cannot delete your own account.');
    }
    await _firestore.collection('users').doc(uid).delete();
  }

  Future<void> updateBranch(String branchId, String newName) async {
    if (newName.isEmpty) return;
    await _firestore.collection('branches').doc(branchId).update({'name': newName});
  }

  Future<void> deleteBranch(String branchId) async {
    await _firestore.collection('branches').doc(branchId).delete();
  }

  @override
  void dispose() {
    _branchSubscription?.cancel();
    _authSubscription?.cancel();
    super.dispose();
  }
}