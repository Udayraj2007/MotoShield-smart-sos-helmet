import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/contact_model.dart';

class ContactService {
  static const String _storageKey = 'emergency_contacts';

  // Maximum Emergency Contacts
  static const int maxContacts = 5;

  /// Load contacts
  Future<List<ContactModel>> loadContacts() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final String? jsonString = prefs.getString(_storageKey);

      if (jsonString == null) {
        return _getInitialContacts();
      }

      final List<dynamic> decoded = jsonDecode(jsonString);

      final List<ContactModel> contacts = decoded
          .map((e) => ContactModel.fromJson(e))
          .toList();

      contacts.sort((a, b) => a.priority.compareTo(b.priority));

      return contacts;
    } catch (e) {
      return _getInitialContacts();
    }
  }

  /// Save contacts
  Future<bool> saveContacts(List<ContactModel> contacts) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final jsonString = jsonEncode(contacts.map((e) => e.toJson()).toList());

      return await prefs.setString(_storageKey, jsonString);
    } catch (e) {
      return false;
    }
  }

  /// Delete all contacts
  Future<void> clearContacts() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
  }

  /// Set a contact as primary
  Future<bool> setPrimaryContact(String id) async {
    final contacts = await loadContacts();
    final updated = contacts.map((c) => c.copyWith(isPrimary: c.id == id)).toList();
    return await saveContacts(updated);
  }

  /// Get Primary Contact (or highest priority contact if none marked)
  Future<ContactModel?> getPrimaryContact() async {
    final contacts = await loadContacts();
    if (contacts.isEmpty) return null;

    final primary = contacts.where((c) => c.isPrimary).firstOrNull;
    if (primary != null) return primary;

    contacts.sort((a, b) => a.priority.compareTo(b.priority));
    return contacts.first;
  }

  /// Indian Mobile Validation
  static bool isValidIndianPhoneNumber(String number) {
    final clean = number.replaceAll(RegExp(r'[\s\-\(\)]'), '');

    return RegExp(r'^(?:\+91|91)?[6-9]\d{9}$').hasMatch(clean);
  }

  /// Convert to +91XXXXXXXXXX
  static String normalizePhoneNumber(String number) {
    final clean = number.replaceAll(RegExp(r'[\s\-\(\)]'), '');

    if (clean.startsWith('+91')) {
      return clean;
    }

    if (clean.startsWith('91') && clean.length > 10) {
      return '+$clean';
    }

    if (clean.length >= 10) {
      return '+91${clean.substring(clean.length - 10)}';
    }

    return '+91$clean';
  }

  /// Future ESP32 Sync
  Future<bool> syncContactsToHelmet(List<ContactModel> contacts) async {
    // TODO:
    // Bluetooth BLE
    // SIM800L
    // ESP32 Contact Sync

    await Future.delayed(const Duration(milliseconds: 1000));

    return true;
  }

  /// First App Launch
  List<ContactModel> _getInitialContacts() {
    return [];
  }
}
