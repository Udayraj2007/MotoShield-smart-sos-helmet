import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'history_model.dart';

class HistoryService {
  static const String _storageKey = 'smart_sos_history_events_v1';
  static final ValueNotifier<int> eventNotifier = ValueNotifier<int>(0);

  // Load history events from SharedPreferences
  Future<List<HistoryModel>> loadHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? jsonString = prefs.getString(_storageKey);
      if (jsonString == null || jsonString.isEmpty) {
        return [];
      }
      final List<dynamic> decoded = jsonDecode(jsonString);
      final List<HistoryModel> list = decoded
          .map((item) => HistoryModel.fromJson(item as Map<String, dynamic>))
          .toList();

      // Sort descending by date (newest first)
      list.sort((a, b) => b.dateTime.compareTo(a.dateTime));
      return list;
    } catch (e) {
      return [];
    }
  }

  // Save history events list
  Future<bool> saveHistory(List<HistoryModel> events) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<Map<String, dynamic>> jsonList = events
          .map((e) => e.toJson())
          .toList();
      final result = await prefs.setString(_storageKey, jsonEncode(jsonList));
      eventNotifier.value++;
      return result;
    } catch (e) {
      return false;
    }
  }

  // Log a single new event
  Future<bool> logEvent(HistoryModel event) async {
    final events = await loadHistory();
    events.insert(0, event); // Add to beginning of list
    return await saveHistory(events);
  }

  // Delete a specific history event
  Future<bool> deleteEvent(String id) async {
    final events = await loadHistory();
    events.removeWhere((e) => e.id == id);
    return await saveHistory(events);
  }

  // Clear all history events
  Future<bool> clearHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final result = await prefs.remove(_storageKey);
      eventNotifier.value++;
      return result;
    } catch (e) {
      return false;
    }
  }

  // Helper static logger for BLE or Crash detection engine calls
  static Future<void> recordEvent({
    required HistoryEventType type,
    required String status,
    required String details,
    double? latitude,
    double? longitude,
    String? locationName,
  }) async {
    final service = HistoryService();
    final event = HistoryModel(
      id: 'evt_${DateTime.now().millisecondsSinceEpoch}',
      eventType: type,
      dateTime: DateTime.now(),
      latitude: latitude,
      longitude: longitude,
      locationName: locationName ?? (latitude != null ? 'GPS Position Locked' : 'Current Location'),
      status: status,
      details: details,
    );
    await service.logEvent(event);
  }
}

