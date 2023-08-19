import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:qr/qr.dart';

import 'package:webview_flutter/webview_flutter.dart';

class BaseWebViewPage extends StatefulWidget {
  final String initialUrl;

  const BaseWebViewPage({Key? key, required this.initialUrl}) : super(key: key);

  @override
  _BaseWebViewPageState createState() => _BaseWebViewPageState();
}


class _BaseWebViewPageState extends State<BaseWebViewPage> {
  bool _isLoading = true;
  late WebViewController _controller;
  String? _currentUrl;
  late QrCode _qrCode;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        WebView(
          initialUrl: widget.initialUrl,
          javascriptMode: JavascriptMode.unrestricted,
          onWebViewCreated: (WebViewController webViewController) {
            _controller = webViewController;
          },
          onPageStarted: (url) {
            setState(() {
              _isLoading = true;
              _currentUrl = url;
              _qrCode = QrCode(4, QrErrorCorrectLevel.L);
              _qrCode.addData(url);
              _qrCode.make();
            });
          },
          onPageFinished: (url) {
            setState(() {
              _isLoading = false;
            });
          },
        ),
        if (_isLoading)
          const Center(child: CircularProgressIndicator()),
        Positioned(
          bottom: 10,
          left: 10,
          child: FloatingActionButton(
            heroTag: null,
            onPressed: () {
              _controller.reload();
            },
            child: const Icon(Icons.refresh),
          ),
        ),
        Positioned(
          bottom: 10,
          right: 10,
          child: FloatingActionButton(
            heroTag: null,
            onPressed: () {
              _showQrCode(context);
            },
            child: const Icon(Icons.qr_code),
          ),
        ),
      ],
    );
  }

  _showQrCode(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("QR Code for Current Page"),
        backgroundColor: !isDarkMode ? Colors.white : Colors.black,
        content: SizedBox(
          width: 200,
          height: 200,
          child: QrImage(
            data: _currentUrl!,
            version: QrVersions.auto,
            size: 200.0,
            // Adjust QR code properties based on the current theme.
            foregroundColor: !isDarkMode ? Colors.black : Colors.white,
            // ... any other QR code customization
          ),

        ),

        actions: [
          TextButton(
            child: Text("Close"),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }
}


