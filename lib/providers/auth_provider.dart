import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_core/firebase_core.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();

  User? _firebaseUser;
  UserModel? _userModel;
  bool _isLoading = true;
  String? _errorMessage;
  StreamSubscription<User?>? _authSubscription;
  StreamSubscription<UserModel?>? _profileSubscription;

  AuthProvider() {
    _init();
  }

  User? get firebaseUser => _firebaseUser;
  UserModel? get userModel => _userModel;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _firebaseUser != null;
  String? get errorMessage => _errorMessage;

  void _init() {
    try {
      if (Firebase.apps.isEmpty) {
        _isLoading = false;
        notifyListeners();
        return;
      }
      _authSubscription = _authService.authStateChanges.listen((User? user) async {
        _firebaseUser = user;
        if (user != null) {
          _listenToUserProfile(user.uid);
        } else {
          _profileSubscription?.cancel();
          _userModel = null;
          _isLoading = false;
          notifyListeners();
        }
      }, onError: (_) {
        _isLoading = false;
        notifyListeners();
      });
    } catch (e) {
      debugPrint('Auth initialization notice: $e');
      _isLoading = false;
      notifyListeners();
    }
  }

  void _listenToUserProfile(String uid) {
    _profileSubscription?.cancel();
    _profileSubscription = _authService.getUserProfileStream(uid).listen((profile) {
      _userModel = profile;
      _isLoading = false;
      notifyListeners();
    }, onError: (err) {
      _isLoading = false;
      notifyListeners();
    });
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  Future<bool> register({
    required String name,
    required String email,
    required String password,
  }) async {
    _setLoading(true);
    _errorMessage = null;
    try {
      _userModel = await _authService.register(
        name: name,
        email: email,
        password: password,
      );
      _setLoading(false);
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      _setLoading(false);
      return false;
    }
  }

  Future<bool> signIn({
    required String email,
    required String password,
  }) async {
    _setLoading(true);
    _errorMessage = null;
    try {
      _userModel = await _authService.signIn(
        email: email,
        password: password,
      );
      _setLoading(false);
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      _setLoading(false);
      return false;
    }
  }

  Future<void> signOut() async {
    _setLoading(true);
    await _authService.signOut();
    _userModel = null;
    _firebaseUser = null;
    _setLoading(false);
  }

  Future<bool> updateProfile({
    String? name,
    String? photoUrl,
    String? phoneNumber,
    String? telebirrNumber,
    String? cbeAccount,
    String? cbeAccountName,
    String? preferredPayment,
  }) async {
    if (_firebaseUser == null) return false;
    _setLoading(true);
    try {
      await _authService.updateUserProfile(
        uid: _firebaseUser!.uid,
        name: name,
        photoUrl: photoUrl,
        phoneNumber: phoneNumber,
        telebirrNumber: telebirrNumber,
        cbeAccount: cbeAccount,
        cbeAccountName: cbeAccountName,
        preferredPayment: preferredPayment,
      );
      if (_userModel != null) {
        _userModel = _userModel!.copyWith(
          name: name,
          photoUrl: photoUrl,
          phoneNumber: phoneNumber,
          telebirrNumber: telebirrNumber,
          cbeAccount: cbeAccount,
          cbeAccountName: cbeAccountName,
          preferredPayment: preferredPayment,
        );
      }
      _setLoading(false);
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      _setLoading(false);
      return false;
    }
  }

  Future<bool> uploadProfilePhoto(XFile file) async {
    if (_firebaseUser == null) return false;
    _setLoading(true);
    try {
      final photoUrl = await _authService.uploadProfileImage(
        uid: _firebaseUser!.uid,
        file: file,
      );
      if (_userModel != null) {
        _userModel = _userModel!.copyWith(photoUrl: photoUrl);
      }
      _setLoading(false);
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      _setLoading(false);
      return false;
    }
  }

  Future<bool> sendPasswordReset(String email) async {
    _setLoading(true);
    try {
      await _authService.sendPasswordReset(email);
      _setLoading(false);
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      _setLoading(false);
      return false;
    }
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _profileSubscription?.cancel();
    super.dispose();
  }
}
