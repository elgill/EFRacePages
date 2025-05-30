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

      // Combine race name and cleaned date
      String eventNameAndDate = '${race.name} - $cleanedDate';

      // JavaScript to find and fill the form field
      final script = '''
        // Function to find the input field by its placeholder text
        function findEventNameField() {
          const inputs = document.querySelectorAll('input[type="text"]');
          for (let input of inputs) {
            if (input.placeholder && input.placeholder.includes('Copy & paste from results page')) {
              return input;
            }
          }
          
          // Alternative: find by label text
          const labels = document.querySelectorAll('label');
          for (let label of labels) {
            if (label.textContent && label.textContent.includes('NAME & DATE OF EVENT')) {
              const forAttr = label.getAttribute('for');
              if (forAttr) {
                return document.getElementById(forAttr);
              }
            }
          }
          
          return null;
        }

        // Find and fill the field
        const eventField = findEventNameField();
        if (eventField) {
          eventField.value = '$eventNameAndDate';
          // Trigger change event in case the form is listening for it
          eventField.dispatchEvent(new Event('input', { bubbles: true }));
          eventField.dispatchEvent(new Event('change', { bubbles: true }));
        }
      ''';

      await controller.evaluateJavascript(source: script);
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
}