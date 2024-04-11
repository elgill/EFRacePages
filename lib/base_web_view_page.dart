import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:webview_flutter/webview_flutter.dart';

class BaseWebViewPage extends StatefulWidget {
  final String initialUrl;

  const BaseWebViewPage({Key? key, required this.initialUrl}) : super(key: key);

  @override
  BaseWebViewPageState createState() => BaseWebViewPageState();
}

class BaseWebViewPageState extends State<BaseWebViewPage> with AutomaticKeepAliveClientMixin {
  bool _isLoading = true;
  late WebViewController _controller;
  String? _currentUrl;
  late QrCode _qrCode;

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);

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
            onPageFinished(url, _controller);
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
              _controller.loadUrl(widget.initialUrl);
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

  void onPageFinished(String url, WebViewController controller) {
    // This can be overridden by subclasses to perform actions after the page finishes loading.
  }

  void _showQrCode(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("QR Code"),
        backgroundColor: !isDarkMode ? Colors.white : Colors.black,
        content: SizedBox(
          width: 200,
          height: 200,
          child: QrImage(
            data: _currentUrl!,
            version: QrVersions.auto,
            size: 200.0,
            foregroundColor: !isDarkMode ? Colors.black : Colors.white,
          ),
        ),
        actions: [
          TextButton(
            child: const Text("Close"),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }
}
