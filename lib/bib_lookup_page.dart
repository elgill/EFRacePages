import 'package:flutter/material.dart';
import 'package:ef_race_pages/base_web_view_page.dart';

class BibLookupPage extends BaseWebViewPage {
  const BibLookupPage({Key? key, required String raceId})
      : super(key: key, initialUrl: "https://www.elitefeats.com/Bibs/?ID=$raceId");
}
