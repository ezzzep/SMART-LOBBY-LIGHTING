import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:smart_lighting/common/widgets/drawer/drawer.dart';
import 'package:smart_lighting/services/service.dart';

class SurveyScreen extends StatefulWidget {
  const SurveyScreen({super.key});

  @override
  SurveyScreenState createState() => SurveyScreenState();
}

class SurveyScreenState extends State<SurveyScreen> {
  final String surveyUrl =
      'https://docs.google.com/forms/d/e/1FAIpQLSeInHMGaZiCYZe5sgPfn2OC-6yYud3E7cggOoZ2JSvdv916JA/viewform?usp=sharing&hl=en';
  bool _showWebView = false;

  @override
  Widget build(BuildContext context) {
    final AuthService _authService = AuthService();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Survey'),
        leading: _showWebView
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  setState(() {
                    _showWebView = false;
                  });
                },
              )
            : Builder(
                builder: (context) => IconButton(
                  icon: const Icon(Icons.menu),
                  onPressed: () => Scaffold.of(context).openDrawer(),
                ),
              ),
      ),
      drawer: DrawerWidget(authService: _authService),
      body: _showWebView
          ? InAppWebView(
              initialUrlRequest: URLRequest(
                url: WebUri(surveyUrl),
                headers: {'Accept-Language': 'en'},
              ),
              initialOptions: InAppWebViewGroupOptions(
                crossPlatform: InAppWebViewOptions(
                  useShouldOverrideUrlLoading: true,
                  javaScriptEnabled: true,
                ),
              ),
              onWebViewCreated: (controller) {
                print('WebView created');
              },
              onLoadStart: (controller, url) {
                print('Loading: $url');
              },
              onLoadStop: (controller, url) {
                print('Loaded: $url');
              },
              onLoadError: (controller, url, code, message) {
                print('Load error: $code, $message');
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Failed to load survey: $message')),
                );
              },
            )
          : Center(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 75),
                    Image.asset(
                      'assets/onboarding/smile.png',
                      height: 150,
                      width: 150,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Would you like to take our survey?',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Your feedback helps us improve the app!',
                      style: TextStyle(fontSize: 16),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ElevatedButton(
                          onPressed: () {
                            print('Yes button tapped'); // Debug log
                            setState(() {
                              _showWebView = true;
                            });
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Color.fromRGBO(83, 166, 234, 1),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 32,
                              vertical: 16,
                            ),
                          ),
                          child: const Text(
                            'Yes',
                            style: TextStyle(fontSize: 18),
                          ),
                        ),
                        const SizedBox(width: 16),
                        ElevatedButton(
                          onPressed: () {
                            print('No button tapped'); // Debug log
                            Navigator.pop(context);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 32,
                              vertical: 16,
                            ),
                          ),
                          child: const Text(
                            'No',
                            style: TextStyle(fontSize: 18),
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
