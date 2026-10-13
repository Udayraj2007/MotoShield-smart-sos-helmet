import 'package:cloud_firestore/cloud_firestore.dart';

class ProfileModel {
  final String uid;
  final String fullName;
  final String email;
  final String phone;
  final String bloodGroup;
  final String dateOfBirth;
  final String photoUrl;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const ProfileModel({
    required this.uid,
    required this.fullName,
    required this.email,
    required this.phone,
    required this.bloodGroup,
    required this.dateOfBirth,
    required this.photoUrl,
    this.createdAt,
    this.updatedAt,
  });

  factory ProfileModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data() ?? {};

    return ProfileModel(
      uid: snapshot.id,
      fullName: data['fullName'] ?? '',
      email: data['email'] ?? '',
      phone: data['phone'] ?? '',
      bloodGroup: data['bloodGroup'] ?? '',
      dateOfBirth: data['dateOfBirth'] ?? '',
      photoUrl: data['photoUrl'] ?? '',
      createdAt: _toDateTime(data['createdAt']),
      updatedAt: _toDateTime(data['updatedAt']),
    );
  }

  factory ProfileModel.fromMap(Map<String, dynamic> data, String uid) {
    return ProfileModel(
      uid: uid,
      fullName: data['fullName'] ?? '',
      email: data['email'] ?? '',
      phone: data['phone'] ?? '',
      bloodGroup: data['bloodGroup'] ?? '',
      dateOfBirth: data['dateOfBirth'] ?? '',
      photoUrl: data['photoUrl'] ?? '',
      createdAt: _toDateTime(data['createdAt']),
      updatedAt: _toDateTime(data['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'fullName': fullName,
      'email': email,
      'phone': phone,
      'bloodGroup': bloodGroup,
      'dateOfBirth': dateOfBirth,
      'photoUrl': photoUrl,
      'createdAt': createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  ProfileModel copyWith({
    String? fullName,
    String? phone,
    String? bloodGroup,
    String? dateOfBirth,
    String? photoUrl,
  }) {
    return ProfileModel(
      uid: uid,
      fullName: fullName ?? this.fullName,
      email: email,
      phone: phone ?? this.phone,
      bloodGroup: bloodGroup ?? this.bloodGroup,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      photoUrl: photoUrl ?? this.photoUrl,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  static DateTime? _toDateTime(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    return null;
  }
}
