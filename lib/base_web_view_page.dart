import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:share_plus/share_plus.dart';

class BaseWebViewPage extends StatefulWidget {
  final String initialUrl;

  const BaseWebViewPage({Key? key, required this.initialUrl}) : super(key: key);

  @override
  BaseWebViewPageState createState() => BaseWebViewPageState();
}

class BaseWebViewPageState extends State<BaseWebViewPage> with AutomaticKeepAliveClientMixin, WidgetsBindingObserver, TickerProviderStateMixin {
  bool _isLoading = true;
  late InAppWebViewController _controller;
  String? _currentUrl;
  late PullToRefreshController _pullToRefreshController;
  bool _controllerReady = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

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
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // When app resumes and controller is ready, check if page needs reload
    if (state == AppLifecycleState.resumed && _controllerReady) {
      _checkAndReloadIfNeeded();
    }
  }

  Future<void> _checkAndReloadIfNeeded() async {
    try {
      // Try to get the current URL from the controller
      final url = await _controller.getUrl();
      // If URL is null or about:blank, reload the initial URL
      if (url == null || url.toString() == 'about:blank') {
        _controller.loadUrl(urlRequest: URLRequest(url: WebUri(widget.initialUrl)));
      }
    } catch (e) {
      // If there's an error accessing the controller, reload
      _controller.loadUrl(urlRequest: URLRequest(url: WebUri(widget.initialUrl)));
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didUpdateWidget(BaseWebViewPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If widget is updated and controller is ready, check if reload is needed
    if (_controllerReady) {
      Future.microtask(() => _checkAndReloadIfNeeded());
    }
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
            _controllerReady = true;
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
          onConsoleMessage: (controller, consoleMessage) {
            print('WebView Console: ${consoleMessage.message}');
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
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Container(
          padding: const EdgeInsets.all(24),
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.9,
            maxHeight: MediaQuery.of(context).size.height * 0.8,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Title
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Share Page",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // QR Code with white background for better scanning
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Center(
                  child: QrImageView(
                    data: _currentUrl!,
                    version: QrVersions.auto,
                    size: 220.0,
                    foregroundColor: Colors.black,
                    backgroundColor: Colors.white,
                    errorCorrectionLevel: QrErrorCorrectLevel.M,
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // URL Display
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDarkMode ? Colors.grey[800] : Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isDarkMode ? Colors.grey[600]! : Colors.grey[300]!,
                  ),
                ),
                child: SelectableText(
                  _currentUrl!,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDarkMode ? Colors.white70 : Colors.black87,
                    fontFamily: 'monospace',
                  ),
                  textAlign: TextAlign.center,
                ),
              ),

              const SizedBox(height: 24),

              // Action Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Copy URL Button
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.copy, size: 18),
                      label: const Text("Copy URL"),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: _currentUrl!));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('URL copied to clipboard'),
                            duration: Duration(seconds: 2),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                        Navigator.of(context).pop();
                      },
                    ),
                  ),

                  const SizedBox(width: 12),

                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.share, size: 18),
                      label: const Text("Share"),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: () async {
                        try {
                          // Try to use shareUri first (better for URL recognition)
                          final uri = Uri.tryParse(_currentUrl!);
                          if (uri != null) {
                            await Share.shareUri(uri);
                          } else {
                            // Fallback to regular share
                            await Share.share(_currentUrl!, subject: 'Check out this page');
                          }
                        } catch (e) {
                          // If shareUri fails (older versions), fall back to regular share
                          await Share.share(_currentUrl!, subject: 'Check out this page');
                        }
                        Navigator.of(context).pop();
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}