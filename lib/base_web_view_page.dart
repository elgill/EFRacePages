import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'gestures/drag_gesture_pull_to_refresh.dart';

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
  final GlobalKey<RefreshIndicatorState> _refreshIndicatorKey = GlobalKey<RefreshIndicatorState>();
  late DragGesturePullToRefresh _dragGesturePullToRefresh;
  bool _isDisposed = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _dragGesturePullToRefresh = DragGesturePullToRefresh(); // Here

    // Initialize the WebViewController
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) {
            _safeSetState(() {
              _isLoading = true;
              _currentUrl = url;
            });
            _dragGesturePullToRefresh.started(); // Here
          },
          onPageFinished: (url) {
            _safeSetState(() {
              _isLoading = false;
            });
            _dragGesturePullToRefresh.finished();
            onPageFinished(url, _controller);
          },
          onWebResourceError: (WebResourceError error) {
            // Hide RefreshIndicator for page reload if showing
            _dragGesturePullToRefresh.finished(); // Here
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.initialUrl));

    _dragGesturePullToRefresh // Here
        .setController(_controller)
        .setDragHeightEnd(200)
        .setDragStartYDiff(10)
        .setWaitToRestart(3000);
  }

  @override
  void dispose() {
    _isDisposed = true;
    _dragGesturePullToRefresh.dispose();
    super.dispose();
  }

  void _safeSetState(VoidCallback fn) {
    if (mounted && !_isDisposed) {
      setState(fn);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return RefreshIndicator(
      key: _refreshIndicatorKey,
      triggerMode: RefreshIndicatorTriggerMode.onEdge,
      onRefresh: _dragGesturePullToRefresh.refresh,
      child: Stack(
        children: [
          Builder(builder: (context) {
            _dragGesturePullToRefresh.setContext(context);

            return WebViewWidget(
              controller: _controller,
              gestureRecognizers: {Factory(() => _dragGesturePullToRefresh)},
            );

          }),
          if (_isLoading)
            const Center(child: CircularProgressIndicator()),
          Positioned(
            bottom: 10,
            left: 10,
            child: FloatingActionButton(
              heroTag: null,
              onPressed: () {
                _controller.loadRequest(Uri.parse(widget.initialUrl));
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
      ),
    );
  }

  void onPageFinished(String url, WebViewController controller) {
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