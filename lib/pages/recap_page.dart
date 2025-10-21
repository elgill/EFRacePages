import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:ef_race_pages/base_web_view_page.dart';
import 'package:ef_race_pages/services/race_service.dart';
import 'package:ef_race_pages/services/recent_event_manager.dart';
import 'package:ef_race_pages/models/race.dart';

class RecapPage extends BaseWebViewPage {
  const RecapPage({Key? key}) : super(key: key, initialUrl: "https://events.elitefeats.com/recap");

  @override
  BaseWebViewPageState createState() => _RecapPageState();
}

class _RecapPageState extends BaseWebViewPageState {

  @override
  void onPageFinished(String url, InAppWebViewController controller) {
    super.onPageFinished(url, controller);
    _autofillEventData(controller);
  }

  Future<void> _autofillEventData(InAppWebViewController controller) async {
    try {
      // Get the current race ID
      String? currentRaceId = await getCurrentRace();
      if (currentRaceId == null) return;

      // Get the race data
      Race? race = await RaceService.getRace(currentRaceId);
      if (race == null) return;

      // Clean the date - remove alphabetic characters and extra spaces
      String cleanedDate = _cleanDate(race.date);

      // Escape strings for JavaScript to prevent injection and syntax errors
      String escapedName = _escapeForJavaScript(race.name);
      String escapedDate = _escapeForJavaScript(cleanedDate);

      // Wait a moment for the form to fully initialize
      await Future.delayed(const Duration(milliseconds: 500));

      // JavaScript to find and fill the form fields (now separate name and date fields)
      final script = '''
        (function() {
          const raceName = "$escapedName";
          const raceDate = "$escapedDate";

          console.log('[Autofill] Starting autofill');
          console.log('[Autofill] Name: ' + raceName);
          console.log('[Autofill] Date: ' + raceDate);

          // Function to fill a field with proper event triggering
          function fillField(field, value) {
            if (!field) return false;

            // Set the value
            field.value = value;

            // Mark as touched/dirty to prevent form resets
            field.setAttribute('data-autofilled', 'true');

            // Focus the field briefly
            field.focus();

            // Trigger all relevant events
            field.dispatchEvent(new Event('input', { bubbles: true }));
            field.dispatchEvent(new Event('change', { bubbles: true }));
            field.dispatchEvent(new Event('blur', { bubbles: true }));

            // For React forms, use native setter
            const nativeInputValueSetter = Object.getOwnPropertyDescriptor(
              window.HTMLInputElement.prototype,
              'value'
            ).set;
            if (nativeInputValueSetter) {
              nativeInputValueSetter.call(field, value);
              field.dispatchEvent(new Event('input', { bubbles: true }));
            }

            console.log('[Autofill] Filled field with: ' + value);
            return true;
          }

          // Find the name and date fields
          let nameField = null;
          let dateField = null;

          const inputs = document.querySelectorAll('input[type="text"]');
          console.log('[Autofill] Found ' + inputs.length + ' text inputs');

          for (let input of inputs) {
            const placeholder = (input.placeholder || '').toLowerCase();
            console.log('[Autofill] Checking placeholder: ' + input.placeholder);

            if (placeholder.includes('event name') && placeholder.includes('copy')) {
              nameField = input;
              console.log('[Autofill] Found name field');
            } else if (placeholder.includes('event date') && placeholder.includes('copy')) {
              dateField = input;
              console.log('[Autofill] Found date field');
            }
          }

          // Fill the fields
          let nameSuccess = false;
          let dateSuccess = false;

          if (nameField) {
            nameSuccess = fillField(nameField, raceName);
          } else {
            console.log('[Autofill] Name field not found');
          }

          if (dateField) {
            dateSuccess = fillField(dateField, raceDate);
          } else {
            console.log('[Autofill] Date field not found');
          }

          return nameSuccess && dateSuccess;
        })();
      ''';

      final result = await controller.evaluateJavascript(source: script);
      if (result != true) {
        print('Warning: Event name field not found or autofill failed');
      }
    } catch (e) {
      print('Error autofilling event data: $e');
    }
  }

  /// Cleans the date string by removing alphabetic characters and extra spaces
  /// Example: "Mon 6/13/25" becomes "6/13/25"
  String _cleanDate(String date) {
    // Remove all alphabetic characters and trim spaces
    String cleaned = date.replaceAll(RegExp(r'[a-zA-Z]'), '').trim();

    // Replace multiple spaces with single space, then trim again
    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();

    return cleaned;
  }

  /// Escapes a string for safe use in JavaScript
  /// Handles quotes, newlines, backslashes, and other special characters
  String _escapeForJavaScript(String str) {
    return str
        .replaceAll('\\', '\\\\')  // Backslash must be first
        .replaceAll('"', '\\"')     // Escape double quotes
        .replaceAll("'", "\\'")     // Escape single quotes
        .replaceAll('\n', '\\n')    // Escape newlines
        .replaceAll('\r', '\\r')    // Escape carriage returns
        .replaceAll('\t', '\\t')    // Escape tabs
        .replaceAll('\b', '\\b')    // Escape backspace
        .replaceAll('\f', '\\f');   // Escape form feed
  }
}