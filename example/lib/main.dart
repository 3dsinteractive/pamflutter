import 'package:flutter/material.dart';
import 'package:pam_flutter/pam.dart';
import './pam_config.dart';

void main() {
  var pamConfig = PamConfigProvider.getConfig();
  Pam.initialize(pamConfig);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Display App Attention if exist

    Pam.appAttention(
      context,
      pageName: "home-video",
      onBannerClick: (bannerData) {
        print("CLICK LEARN MORE.");
        print(bannerData.toString());
        return false;
      },
    );

    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  void _allowConsent() async {
    var trackingConsentMessageID =
        Pam.shared.config?.trackingConsentMessageID ?? "";

    var trackingConsent =
        await Pam.loadConsentMessage(trackingConsentMessageID);
    trackingConsent?.allowAll();

    if (trackingConsent != null) {
      await Pam.submitConsent(trackingConsent);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            ElevatedButton(
              onPressed: () {
                // เมื่อคลิกปุ่มให้แสดงข้อความใน console
                _allowConsent();
              },
              child: Text('Click Me'),
            ),
          ],
        ),
      ),
    );
  }
}
