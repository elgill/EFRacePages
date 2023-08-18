import 'package:flutter/material.dart';
import 'package:ef_race_pages/base_web_view_page.dart';

class ResultsPage extends BaseWebViewPage {
  const ResultsPage({Key? key, required String raceId})
      : super(key: key, initialUrl: "https://www.elitefeats.com/race-results.asp?ID=$raceId");
}
