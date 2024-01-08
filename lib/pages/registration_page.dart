import 'package:flutter/material.dart';
import 'package:ef_race_pages/base_web_view_page.dart';

class RegistrationPage extends BaseWebViewPage {
  const RegistrationPage({Key? key, required String raceId})
      : super(key: key, initialUrl: "https://www.elitefeats.com/upcoming-detail.asp?ID=$raceId");
}
