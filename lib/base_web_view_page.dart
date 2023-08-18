import 'package:flutter/material.dart';
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
      ],
    );
  }
}
