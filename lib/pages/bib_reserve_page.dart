import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:ef_race_pages/base_web_view_page.dart';

class BibReservePage extends BaseWebViewPage {
  final String raceId;

  const BibReservePage({Key? key, required this.raceId})
      : super(key: key, initialUrl: "https://www.elitefeats.com/bibreserve");

  @override
  BaseWebViewPageState createState() => _BibReservePageState(raceId);
}

class _BibReservePageState extends BaseWebViewPageState {
  final String raceId;

  _BibReservePageState(this.raceId);

  @override
  void onPageFinished(String url, InAppWebViewController controller) {
    super.onPageFinished(url, controller);
    // Inject JavaScript code to set the value of the race ID input element.
    final script = "document.getElementById('txtUserId').value = '$raceId';";
    controller.evaluateJavascript(source: script);
  }
}