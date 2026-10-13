import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../models/profile_model.dart';

class ProfileService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _profiles =>
      _firestore.collection('profiles');

  User? get currentUser => _auth.currentUser;

  Future<ProfileModel?> getProfile() async {
    final user = _auth.currentUser;

    if (user == null) {
      return null;
    }

    final doc = await _profiles.doc(user.uid).get();

    if (!doc.exists) {
      return null;
    }

    return ProfileModel.fromFirestore(doc);
  }

  Future<ProfileModel> createProfileIfNeeded() async {
    final user = _auth.currentUser;

    if (user == null) {
      throw Exception('No authenticated user found.');
    }

    final docRef = _profiles.doc(user.uid);
    final snapshot = await docRef.get();

    if (snapshot.exists) {
      return ProfileModel.fromFirestore(snapshot);
    }

    final profile = ProfileModel(
      uid: user.uid,
      fullName: user.displayName ?? '',
      email: user.email ?? '',
      phone: user.phoneNumber ?? '',
      bloodGroup: '',
      dateOfBirth: '',
      photoUrl: user.photoURL ?? '',
      createdAt: DateTime.now(),
    );

    await docRef.set(profile.toMap());

    return profile;
  }

  Future<void> updateProfile({
    required String fullName,
    required String phone,
    required String bloodGroup,
    required String dateOfBirth,
    String? photoUrl,
  }) async {
    final user = _auth.currentUser;

    if (user == null) {
      throw Exception('No authenticated user found.');
    }

    await _profiles.doc(user.uid).set({
      'fullName': fullName.trim(),
      'phone': phone.trim(),
      'bloodGroup': bloodGroup.trim(),
      'dateOfBirth': dateOfBirth.trim(),
      if (photoUrl != null) 'photoUrl': photoUrl,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // Firebase Authentication profile bhi update karenge.
    if (fullName.trim().isNotEmpty) {
      await user.updateDisplayName(fullName.trim());
    }

    if (photoUrl != null && photoUrl.trim().isNotEmpty) {
      await user.updatePhotoURL(photoUrl.trim());
    }

    await user.reload();
  }

  Future<void> updatePhotoUrl(String photoUrl) async {
    final user = _auth.currentUser;

    if (user == null) {
      throw Exception('No authenticated user found.');
    }

    await _profiles.doc(user.uid).set({
      'photoUrl': photoUrl.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await user.updatePhotoURL(photoUrl.trim());
    await user.reload();
  }

  Future<void> logout() async {
    await _auth.signOut();
  }

  Future<void> reauthenticateWithPassword(String password) async {
    final user = _auth.currentUser;
    if (user == null || user.email == null) {
      throw Exception('No authenticated user found.');
    }
    final credential = EmailAuthProvider.credential(
      email: user.email!,
      password: password.trim(),
    );
    await user.reauthenticateWithCredential(credential);
  }

  static const String _webClientId =
      '408287684998-53o0evqctql1dgamoejs48ks06d84kl8.apps.googleusercontent.com';

  Future<void> reauthenticateWithGoogle() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('No authenticated user found.');
    }
    if (kIsWeb) {
      final GoogleAuthProvider googleProvider = GoogleAuthProvider();
      await user.reauthenticateWithPopup(googleProvider);
    } else {
      final GoogleSignIn googleSignIn = GoogleSignIn.instance;
      await googleSignIn.initialize(
        serverClientId: _webClientId,
      );
      final GoogleSignInAccount googleUser =
          await googleSignIn.authenticate();
      final GoogleSignInAuthentication googleAuth =
          googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );
      await user.reauthenticateWithCredential(credential);
    }
  }

  Future<void> deleteAccount() async {
    final user = _auth.currentUser;
    if (user != null) {
      try {
        await _profiles.doc(user.uid).delete();
      } catch (_) {}
      await user.delete();
    }
  }
}
