import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import '../models/user_model.dart';

class AuthService {
  FirebaseAuth get _auth => FirebaseAuth.instance;
  FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  Stream<User?> get authStateChanges => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  /// Register a new student user with email and password, creating their profile in Firestore.
  Future<UserModel> register({
    required String name,
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final user = credential.user;
      if (user == null) {
        throw Exception('User creation failed');
      }

      // Update Firebase Auth display name
      await user.updateDisplayName(name.trim());

      final newUser = UserModel(
        uid: user.uid,
        name: name.trim(),
        email: email.trim(),
        rating: 0.0,
        ratingCount: 0,
        joinedAt: DateTime.now(),
      );

      // Save user profile in Firestore
      await _firestore.collection('users').doc(user.uid).set(newUser.toMap());

      return newUser;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw Exception('Registration error: ${e.toString()}');
    }
  }

  /// Sign in an existing student user with email and password.
  Future<UserModel> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final user = credential.user;
      if (user == null) {
        throw Exception('Sign in failed');
      }

      final profile = await getUserProfile(user.uid);
      if (profile != null) {
        return profile;
      }

      // If doc does not exist yet (edge case), create it
      final fallbackUser = UserModel(
        uid: user.uid,
        name: user.displayName ?? 'Campus Student',
        email: user.email ?? email.trim(),
        rating: 0.0,
        ratingCount: 0,
        joinedAt: DateTime.now(),
      );
      await _firestore.collection('users').doc(user.uid).set(fallbackUser.toMap());
      return fallbackUser;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw Exception('Sign in error: ${e.toString()}');
    }
  }

  /// Sign out the current user.
  Future<void> signOut() async {
    await _auth.signOut();
  }

  /// Fetch user profile by UID.
  Future<UserModel?> getUserProfile(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        return UserModel.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      debugPrint('Error fetching user profile: $e');
      return null;
    }
  }

  /// Stream user profile in real-time.
  Stream<UserModel?> getUserProfileStream(String uid) {
    return _firestore
        .collection('users')
        .doc(uid)
        .snapshots()
        .map((doc) => doc.exists ? UserModel.fromFirestore(doc) : null);
  }

  /// Update user profile details (name, photoUrl, and Ethiopian payment credentials).
  Future<void> updateUserProfile({
    required String uid,
    String? name,
    String? photoUrl,
    String? phoneNumber,
    String? telebirrNumber,
    String? cbeAccount,
    String? cbeAccountName,
    String? preferredPayment,
  }) async {
    final Map<String, dynamic> updates = {};
    if (name != null && name.trim().isNotEmpty) {
      updates['name'] = name.trim();
      try {
        await _auth.currentUser?.updateDisplayName(name.trim());
      } catch (e) {
        debugPrint('DisplayName update notice: $e');
      }
    }
    if (photoUrl != null) {
      updates['photoUrl'] = photoUrl;
      // CRITICAL: Firebase Auth's updatePhotoURL() strictly requires a valid http/https URL.
      // Passing data: URLs or large Base64 strings causes an unhandled exception on Android.
      if ((photoUrl.startsWith('http://') || photoUrl.startsWith('https://')) && photoUrl.length < 2000) {
        try {
          await _auth.currentUser?.updatePhotoURL(photoUrl);
        } catch (e) {
          debugPrint('Auth photoURL notice: $e');
        }
      }
    }

    if (phoneNumber != null) updates['phoneNumber'] = phoneNumber.trim();
    if (telebirrNumber != null) updates['telebirrNumber'] = telebirrNumber.trim();
    if (cbeAccount != null) updates['cbeAccount'] = cbeAccount.trim();
    if (cbeAccountName != null) updates['cbeAccountName'] = cbeAccountName.trim();
    if (preferredPayment != null) updates['preferredPayment'] = preferredPayment;

    if (updates.isNotEmpty) {
      await _firestore.collection('users').doc(uid).set(updates, SetOptions(merge: true));
    }
  }

  /// Upload a profile image.
  /// Converts the image into a clean Base64 Data URI stored directly in the student's Firestore profile,
  /// ensuring 100% offline reliability without failing on external cloud quotas or missing storage buckets.
  Future<String> uploadProfileImage({
    required String uid,
    required XFile file,
  }) async {
    try {
      final bytes = await file.readAsBytes();
      final base64String = base64Encode(bytes);
      final dataUrl = 'data:image/jpeg;base64,$base64String';

      await updateUserProfile(uid: uid, photoUrl: dataUrl);
      return dataUrl;
    } catch (e) {
      debugPrint('Error uploading profile image: $e');
      rethrow;
    }
  }

  /// Send password reset email.
  Future<void> sendPasswordReset(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  String _handleAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No student account found with this email.';
      case 'wrong-password':
        return 'Incorrect password. Please try again.';
      case 'email-already-in-use':
        return 'An account already exists for this email.';
      case 'invalid-email':
        return 'The email address is formatted incorrectly.';
      case 'weak-password':
        return 'Password must be at least 6 characters.';
      case 'user-disabled':
        return 'This account has been disabled.';
      default:
        return e.message ?? 'Authentication error occurred.';
    }
  }
}
