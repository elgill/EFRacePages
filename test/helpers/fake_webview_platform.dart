// A minimal in-memory implementation of the flutter_inappwebview platform
// interface so pages built on BaseWebViewPage can be pumped in widget tests.
//
// Real webviews are platform views and cannot run under `flutter test`. This
// fake renders a placeholder and lets a test drive the webview lifecycle by
// hand (created / load start / load stop / error), which is exactly what we
// need to reproduce callback-ordering bugs.
import 'package:flutter/widgets.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

class FakeInAppWebViewPlatform extends InAppWebViewPlatform {
  /// Every webview widget created since the last [reset], oldest first.
  final List<FakeWebView> webViews = [];
  final List<FakePullToRefreshController> pullToRefreshControllers = [];
  int deleteAllCookiesCalls = 0;
  Object? deleteAllCookiesError;

  static final FakeInAppWebViewPlatform _shared = FakeInAppWebViewPlatform();

  /// Installs the fake and clears its recorded state. A single shared
  /// instance is used because flutter_inappwebview caches singletons such
  /// as `CookieManager.instance()` that would otherwise keep pointing at a
  /// previous test's fake.
  static FakeInAppWebViewPlatform install() {
    _shared
      ..webViews.clear()
      ..pullToRefreshControllers.clear()
      ..deleteAllCookiesCalls = 0
      ..deleteAllCookiesError = null;
    InAppWebViewPlatform.instance = _shared;
    return _shared;
  }

  /// The webview whose initial URL matches [url] (most recent first).
  FakeWebView byInitialUrl(String url) => webViews.lastWhere(
      (w) => w.initialUrl == url,
      orElse: () => throw StateError(
          'No webview with initial URL $url. Have: ${webViews.map((w) => w.initialUrl).toList()}'));

  @override
  PlatformInAppWebViewWidget createPlatformInAppWebViewWidget(
      PlatformInAppWebViewWidgetCreationParams params) {
    final w = FakeWebView(params);
    webViews.add(w);
    return w;
  }

  @override
  PlatformPullToRefreshController createPlatformPullToRefreshController(
      PlatformPullToRefreshControllerCreationParams params) {
    final c = FakePullToRefreshController(params);
    pullToRefreshControllers.add(c);
    return c;
  }

  @override
  PlatformCookieManager createPlatformCookieManager(
      PlatformCookieManagerCreationParams params) {
    return _FakeCookieManager(params, this);
  }
}

class FakeWebView extends PlatformInAppWebViewWidget {
  FakeWebView(super.params) : super.implementation();

  final FakeWebViewController controller = FakeWebViewController();
  bool disposed = false;

  String? get initialUrl => params.initialUrlRequest?.url?.toString();

  InAppWebViewController get _appController =>
      params.controllerFromPlatform!(controller) as InAppWebViewController;

  /// Simulates the native view finishing creation.
  void fireCreated() => params.onWebViewCreated?.call(_appController);

  void fireLoadStart(String url) {
    controller.currentUrl = WebUri(url);
    params.onLoadStart?.call(_appController, WebUri(url));
  }

  void fireLoadStop(String url) =>
      params.onLoadStop?.call(_appController, WebUri(url));

  void fireError(String url) => params.onReceivedError?.call(
        _appController,
        WebResourceRequest(url: WebUri(url)),
        WebResourceError(type: WebResourceErrorType.UNKNOWN, description: 'x'),
      );

  @override
  Widget build(BuildContext context) =>
      const SizedBox.expand(key: ValueKey('fake-webview'));

  @override
  T controllerFromPlatform<T>(PlatformInAppWebViewController controller) =>
      InAppWebViewController.fromPlatform(platform: controller) as T;

  @override
  void dispose() => disposed = true;
}

class FakeWebViewController extends PlatformInAppWebViewController {
  FakeWebViewController()
      : super.implementation(
            const PlatformInAppWebViewControllerCreationParams(id: 'fake'));

  WebUri? currentUrl;
  final List<String> loadedUrls = [];
  final List<String> evaluatedScripts = [];
  int reloadCalls = 0;

  /// When set, [getUrl] throws this instead of returning.
  Object? getUrlError;

  @override
  Future<WebUri?> getUrl() async {
    if (getUrlError != null) throw getUrlError!;
    return currentUrl;
  }

  @override
  Future<void> loadUrl(
      {required URLRequest urlRequest,
      Uri? iosAllowingReadAccessTo,
      WebUri? allowingReadAccessTo}) async {
    loadedUrls.add(urlRequest.url.toString());
  }

  @override
  Future<void> reload() async => reloadCalls++;

  @override
  Future<dynamic> evaluateJavascript(
      {required String source, ContentWorld? contentWorld}) async {
    evaluatedScripts.add(source);
    return true;
  }

  @override
  void dispose({bool isKeepAlive = false}) {}
}

class FakePullToRefreshController extends PlatformPullToRefreshController {
  FakePullToRefreshController(super.params) : super.implementation();

  int endRefreshingCalls = 0;

  /// Simulates the user pulling down to refresh.
  void pull() => params.onRefresh?.call();

  @override
  Future<void> endRefreshing() async => endRefreshingCalls++;

  @override
  void dispose({bool isKeepAlive = false}) {}
}

class _FakeCookieManager extends PlatformCookieManager {
  _FakeCookieManager(super.params, this._platform) : super.implementation();
  final FakeInAppWebViewPlatform _platform;

  @override
  Future<bool> deleteAllCookies() async {
    _platform.deleteAllCookiesCalls++;
    if (_platform.deleteAllCookiesError != null) {
      throw _platform.deleteAllCookiesError!;
    }
    return true;
  }
}
