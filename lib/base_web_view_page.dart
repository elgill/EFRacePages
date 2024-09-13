import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:flutter/gestures.dart';

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
  final GlobalKey<RefreshIndicatorState> _refreshIndicatorKey = GlobalKey<RefreshIndicatorState>();
  late DragGesturePullToRefresh _dragGesturePullToRefresh;
  bool _isDisposed = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _dragGesturePullToRefresh = DragGesturePullToRefresh();
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

    // Set the height of the drag gesture recognizer
    _dragGesturePullToRefresh.setHeight(MediaQuery.of(context).size.height);

    return RefreshIndicator(
      key: _refreshIndicatorKey,
      onRefresh: () => _dragGesturePullToRefresh.refresh(),
      child: Stack(
        children: [
          Builder(
            builder: (BuildContext context) => WebView(
              initialUrl: widget.initialUrl,
              javascriptMode: JavascriptMode.unrestricted,
              gestureRecognizers: {Factory(() => _dragGesturePullToRefresh)},
              onWebViewCreated: (WebViewController webViewController) {
                _controller = webViewController;
                _dragGesturePullToRefresh
                    .setContext(context)
                    .setController(_controller);
              },
              onPageStarted: (url) {
                _safeSetState(() {
                  _isLoading = true;
                  _currentUrl = url;
                  _qrCode = QrCode(4, QrErrorCorrectLevel.L);
                  _qrCode.addData(url);
                  _qrCode.make();
                });
                _dragGesturePullToRefresh.started();
              },
              onPageFinished: (url) {
                _safeSetState(() {
                  _isLoading = false;
                });
                _dragGesturePullToRefresh.finished();
                onPageFinished(url, _controller);
              },
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
      ),
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

class DragGesturePullToRefresh extends VerticalDragGestureRecognizer {
  static const double EXCEEDS_LOADING_TIME = 3000;

  late BuildContext _context;
  late WebViewController _controller;

  // loading
  Completer<void> completer = Completer<void>();
  int msLoading = 0;
  bool isLoading = true;

  // drag
  double height = 200;
  bool dragStarted = false;
  double dragDistance = 0;

  @override
  void rejectGesture(int pointer) {
    acceptGesture(pointer);
  }

  void _clearDrag() {
    dragStarted = false;
    dragDistance = 0;
  }

  DragGesturePullToRefresh setContext(BuildContext context) { _context = context; return this; }
  DragGesturePullToRefresh setController(WebViewController controller) { _controller = controller; return this; }

  void setHeight(double height) { this.height = height; }

  Future<void> refresh() {
    if (!completer.isCompleted) {
      completer.complete();
    }
    completer = Completer<void>();
    started();
    _controller.reload();
    return completer.future;
  }

  void started() {
    msLoading = DateTime.now().millisecondsSinceEpoch;
    isLoading = true;
  }

  void finished() {
    msLoading = 0;
    isLoading = false;
    if (!completer.isCompleted) {
      completer.complete();
    }
  }

  FixedScrollMetrics _getMetrics(double minScrollExtent, double maxScrollExtent,
      double pixels, double viewportDimension, AxisDirection axisDirection) {
    return FixedScrollMetrics(
        minScrollExtent: minScrollExtent,
        maxScrollExtent: maxScrollExtent,
        pixels: pixels,
        viewportDimension: viewportDimension,
        axisDirection: axisDirection, devicePixelRatio: 1.0);
  }

  DragGesturePullToRefresh() {
    onStart = (DragStartDetails dragDetails) {
      if (!isLoading ||
          (msLoading > 0 && (DateTime.now().millisecondsSinceEpoch - msLoading) > EXCEEDS_LOADING_TIME)) {
        _controller.getScrollY().then((scrollYPos) {
          if (scrollYPos == 0) {
            dragStarted = true;
            dragDistance = 0;
            ScrollStartNotification(
                metrics: _getMetrics(0, height, 0, height, AxisDirection.down),
                dragDetails: dragDetails,
                context: _context)
                .dispatch(_context);
          }
        });
      }
    };
    onUpdate = (DragUpdateDetails dragDetails) {
      if (dragStarted) {
        double dy = dragDetails.delta.dy;
        dragDistance += dy;
        ScrollUpdateNotification(
            metrics: _getMetrics(
                dy > 0 ? 0 : dragDistance, height,
                dy > 0 ? (-1) * dy : dragDistance, height,
                dragDistance < 0 ? AxisDirection.up : AxisDirection.down),
            context: _context,
            scrollDelta: (-1) * dy)
            .dispatch(_context);
        if (dragDistance < 0) {
          _clearDrag();
        }
      }
    };
    onEnd = (DragEndDetails dragDetails) {
      ScrollEndNotification(
          metrics: _getMetrics(0, height, dragDistance, height, AxisDirection.down),
          context: _context)
          .dispatch(_context);
      _clearDrag();
    };
    onCancel = () {
      ScrollUpdateNotification(
          metrics: _getMetrics(0, height, 1, height, AxisDirection.up),
          context: _context,
          scrollDelta: 0)
          .dispatch(_context);
      _clearDrag();
    };
  }
}