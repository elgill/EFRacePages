import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

class BaseWebViewPage extends StatefulWidget {
  final String initialUrl;

  const BaseWebViewPage({Key? key, required this.initialUrl}) : super(key: key);

  @override
  BaseWebViewPageState createState() => BaseWebViewPageState();
}

class BaseWebViewPageState extends State<BaseWebViewPage> with AutomaticKeepAliveClientMixin {
  bool _isLoading = true;
  late InAppWebViewController _controller;
  String? _currentUrl;
  late PullToRefreshController _pullToRefreshController;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();

    _pullToRefreshController = PullToRefreshController(
      settings: PullToRefreshSettings(
        color: Colors.blue,
      ),
      onRefresh: () async {
        // Explicitly reload the current page
        await _controller.reload();
      },
    );
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Stack(
      children: [
        InAppWebView(
          initialUrlRequest: URLRequest(url: WebUri(widget.initialUrl)),
          pullToRefreshController: _pullToRefreshController,
          onWebViewCreated: (controller) {
            _controller = controller;
          },
          onLoadStart: (controller, url) {
            setState(() {
              _isLoading = true;
              _currentUrl = url?.toString();
            });
          },
          onLoadStop: (controller, url) async {
            setState(() {
              _isLoading = false;
            });
            _pullToRefreshController.endRefreshing();
            onPageFinished(url?.toString() ?? '', controller);
          },
          onReceivedError: (controller, request, error) {
            _pullToRefreshController.endRefreshing();
          },
          initialSettings: InAppWebViewSettings(
            useShouldOverrideUrlLoading: false,
            mediaPlaybackRequiresUserGesture: false,
            allowsInlineMediaPlayback: true,
            iframeAllow: "camera; microphone",
            iframeAllowFullscreen: true,
          ),
        ),
        if (_isLoading)
          const Center(child: CircularProgressIndicator()),
        Positioned(
          bottom: 10,
          left: 10,
          child: FloatingActionButton(
            heroTag: null,
            onPressed: () {
              _controller.loadUrl(urlRequest: URLRequest(url: WebUri(widget.initialUrl)));
            },
            child: const Icon(Icons.home),
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

  void onPageFinished(String url, InAppWebViewController controller) {
    // This can be overridden by subclasses to perform actions after the page finishes loading.
  }

  void _showQrCode(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    if (_currentUrl == null) {
      return; // Don't show QR code if URL is null
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("QR Code"),
        backgroundColor: !isDarkMode ? Colors.white : Colors.black,
        content: SizedBox(
          width: 200,
          height: 200,
          child: QrImageView(
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