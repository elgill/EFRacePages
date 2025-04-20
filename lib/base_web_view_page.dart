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

class DragGesturePullToRefresh extends VerticalDragGestureRecognizer {
  static const int exceedsLoadingTime = 3000;

  late BuildContext _context;
  late WebViewController _controller;

  // loading
  Completer<void> completer = Completer<void>();
  late int msWaitToRestart;
  int msLoading = 0;
  bool isLoading = true;
  Timer? _timeoutTimer;

  // drag
  int dragStartYDiff = 0;
  double dragHeightEnd = 200;
  bool dragStarted = false;
  double dragDistance = 0;

  @override
  //override rejectGesture here
  void rejectGesture(int pointer) {
    acceptGesture(pointer);
  }

  void _clearDrag() {
    dragStarted = false;
    dragDistance = 0;
    _cancelTimeoutTimer();
  }

  void _cancelTimeoutTimer() {
    _timeoutTimer?.cancel();
    _timeoutTimer = null;
  }

  /// [context] RefreshIndicator
  DragGesturePullToRefresh setContext(BuildContext context) {
    _context = context;
    return this;
  }

  /// [controller] WebViewController
  DragGesturePullToRefresh setController(WebViewController controller) {
    _controller = controller;
    return this;
  }

  /// [dragHeightEnd] End height for starting the refresh
  DragGesturePullToRefresh setDragHeightEnd(double value) {
    dragHeightEnd = value;
    return this;
  }

  /// [msWaitToRestart] milliseconds to reallow pull to refresh if the website
  /// didn't load in msWaitToRestart time
  DragGesturePullToRefresh setWaitToRestart(int value) {
    msWaitToRestart = value;
    return this;
  }

  /// [dragStartYDiff] add some offset as page top is not always obviously page top, e.g. 10
  DragGesturePullToRefresh setDragStartYDiff(int value) {
    dragStartYDiff = value;
    return this;
  }

  /// start refresh
  Future<void> refresh() {
    if (!completer.isCompleted) {
      completer.complete();
    }
    completer = Completer<void>();
    started();
    _controller.reload();

    // Set a timeout to force complete the refresh if it takes too long
    _timeoutTimer = Timer(Duration(milliseconds: msWaitToRestart), () {
      if (!completer.isCompleted) {
        completer.complete();
        finished();
      }
    });

    return completer.future;
  }

  /// Loading started
  void started() {
    msLoading = DateTime.now().millisecondsSinceEpoch;
    isLoading = true;
  }

  /// Loading finished
  void finished() {
    msLoading = 0;
    isLoading = false;
    _cancelTimeoutTimer();

    // hide the RefreshIndicator
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
        axisDirection: axisDirection,
        devicePixelRatio: 1);
  }

  /// [msWaitToRestart] milliseconds to reallow pull to refresh if the website
  /// didn't load in msWaitToRestart time
  ///
  /// [dragStartYDiff] add some offset as page top is not always obviously page top, e.g. 10
  DragGesturePullToRefresh([this.msWaitToRestart = exceedsLoadingTime, this.dragStartYDiff = 0]) {
    onStart = (DragStartDetails dragDetails) async {
      //debugPrint('DragGesturePullToRefresh(): $dragDetails');
      if (!isLoading ||
          // Reallow pull to refresh if the website didn't load in msWaitToRestart time
          (msLoading > 0 && (DateTime.now().millisecondsSinceEpoch - msLoading) > msWaitToRestart)) {
        Offset scrollPos = await _controller.getScrollPosition();

        // Only allow RefreshIndicator if you are at the top of page!
        if (scrollPos.dy <= dragStartYDiff) {
          dragStarted = true;
          dragDistance = 0;
          ScrollStartNotification(
              metrics: _getMetrics(
                  0, dragHeightEnd, 0, dragHeightEnd, AxisDirection.down),
              dragDetails: dragDetails,
              context: _context)
              .dispatch(_context);
        }
      }
    };
    onUpdate = (DragUpdateDetails dragDetails) {
      if (dragStarted) {
        double dy = dragDetails.delta.dy;
        dragDistance += dy;
        ScrollUpdateNotification(
            metrics: _getMetrics(
                dy > 0 ? 0 : dragDistance,
                dragHeightEnd,
                dy > 0 ? (-1) * dy : dragDistance,
                dragHeightEnd,
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
      if (dragStarted) {
        ScrollEndNotification(
            metrics: _getMetrics(0, dragHeightEnd, dragDistance, dragHeightEnd,
                AxisDirection.down),
            context: _context)
            .dispatch(_context);
        _clearDrag();
      }
    };
    onCancel = () {
      if (dragStarted) {
        ScrollUpdateNotification(
            metrics: _getMetrics(
                0, dragHeightEnd, 1, dragHeightEnd, AxisDirection.up),
            context: _context,
            scrollDelta: 0)
            .dispatch(_context);
        _clearDrag();
      }
    };
  }

  @override
  void dispose() {
    _cancelTimeoutTimer();
    super.dispose();
  }
}