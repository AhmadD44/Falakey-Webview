import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:lottie/lottie.dart';
import 'dart:async'; // Add this import for StreamSubscription

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Professional WebView App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const FullScreenWebView(),
    );
  }
}

class FullScreenWebView extends StatefulWidget {
  const FullScreenWebView({super.key});

  @override
  State<FullScreenWebView> createState() => _FullScreenWebViewState();
}

class _FullScreenWebViewState extends State<FullScreenWebView> {
  late WebViewController _webViewController;
  bool _isConnected = true;
  bool _isLoading = true;
  final Connectivity _connectivity = Connectivity();
  StreamSubscription? _connectivitySubscription;

  // Replace with your website URL
  final String _url = 'https://falakey.com';

  @override
  void initState() {
    super.initState();
    _initConnectivity();
    _initWebViewController(); // This includes Step 4 configuration
    _setupConnectivityListener();
  }

  Future<void> _initConnectivity() async {
    final connectivityResult = await _connectivity.checkConnectivity();
    setState(() {
      _isConnected = connectivityResult != ConnectivityResult.none;
    });
  }

  void _setupConnectivityListener() {
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
      (ConnectivityResult result) {
        final isNowConnected = result != ConnectivityResult.none;
        if (isNowConnected && !_isConnected) {
          // Connection restored - reload webview
          _reloadWebView();
        }
        setState(() {
          _isConnected = isNowConnected;
        });
      },
    );
  }

  // STEP 4 GOES HERE - Advanced WebView Configuration
  void _initWebViewController() {
    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      // Advanced JavaScript configuration
      ..enableZoom(false) // Disable zoom for better control
      // ..enableDomStorage(true) // Enable DOM storage
      
      // Add JavaScript channels if needed
      ..addJavaScriptChannel(
        'Flutter',
        onMessageReceived: (JavaScriptMessage message) {
          // Handle JavaScript messages from web
          print('JavaScript message: ${message.message}');
        },
      )
      
      // Set custom user agent (optional)
      ..setUserAgent('Mozilla/5.0 (Linux; Android 10; Mobile) AppleWebKit/537.36')
      
      // Navigation delegate
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            setState(() {
              _isLoading = progress < 100;
            });
          },
          onPageStarted: (String url) {
            setState(() {
              _isLoading = true;
            });
          },
          onPageFinished: (String url) {
            setState(() {
              _isLoading = false;
            });
            
            // Inject custom JavaScript after page loads
            _webViewController.runJavaScript(
              '''
              // Your custom JavaScript here
              console.log('Page loaded successfully from Flutter WebView');
              
              // Example: Send message to Flutter
              if (typeof Flutter !== 'undefined') {
                Flutter.postMessage('Page loaded: ' + window.location.href);
              }
              '''
            );
          },
          onWebResourceError: (WebResourceError error) {
            setState(() {
              _isLoading = false;
            });
            print('Web resource error: ${error.description}');
          },
          onNavigationRequest: (NavigationRequest request) {
            // Allow all navigation by default
            // You can add custom logic here to block certain URLs
            print('Navigation to: ${request.url}');
            return NavigationDecision.navigate;
          },
          onUrlChange: (UrlChange change) {
            print('URL changed to: ${change.url}');
          },
        ),
      )
      ..loadRequest(Uri.parse(_url));
  }

  void _reloadWebView() {
    if (_webViewController != null) {
      _webViewController.reload();
    }
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    super.dispose();
  }

  @override
Widget build(BuildContext context) {
  return WillPopScope(
    onWillPop: () async {
      if (await _webViewController.canGoBack()) {
        _webViewController.goBack();
        return false; // ⛔ don't exit app
      }
      return true; // ✅ exit if no web history
    },
    child: AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.black,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        body: _buildBody(),
      ),
    ),
  );
}


  Widget _buildBody() {
    if (!_isConnected) {
      return _buildNoConnectionScreen();
    }

    return Stack(
      children: [
        WebViewWidget(controller: _webViewController),
        if (_isLoading)
          Container(
            color: Colors.white,
            child: const Center(
              child: CircularProgressIndicator(),
            ),
          ),
      ],
    );
  }

  Widget _buildNoConnectionScreen() {
    return Container(
      color: Colors.white,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Option 1: Lottie Animation (Recommended)
          // Make sure you have the Lottie JSON file in assets/animations/
          Lottie.asset(
            'assets/animations/no-internet.json',
            width: 300,
            height: 300,
            repeat: true,
            // If you don't have Lottie, use the fallback below
          ),
          
          // Option 2: Fallback Icon (if Lottie not available)
          /*
          Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.grey[100],
            ),
            child: const Center(
              child: Icon(
                Icons.wifi_off,
                size: 100,
                color: Colors.grey[400],
              ),
            ),
          ),
          */
          
          const SizedBox(height: 30),
          const Text(
            'No Internet Connection',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 15),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'Please check your internet connection and try again',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.black54,
              ),
            ),
          ),
          const SizedBox(height: 30),
          ElevatedButton.icon(
            onPressed: _reloadWebView,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry Connection'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
          ),
        ],
      ),
    );
  }
}