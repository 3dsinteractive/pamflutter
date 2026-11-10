import 'package:flutter/material.dart';
import 'package:pam_flutter/pam.dart';
import './pam_config.dart';

PamUserState identityProvider() {
  // if no Status
  return PamUserState.unknown();

  // // if not login yet
  // return const PamUserState.anonymous();

  // // if logged in
  // return PamUserState.loggedIn(
  //   identity: PamIdentity(
  //     value: "member-id-123",
  //     type: PamIdentityType.customer,
  //   ),
  // );
}

Future<void> onIdentityMismatch(PamIdentityMismatch mismatch) async {
  final identity = mismatch.newIdentity;
  if (identity == null) {
    Pam.userLogout();
  } else {
    Pam.userLogin(identity.value);
  }
}

void consent() async {
  Pam.loadConsentStatus("xxx").then(
    (userConsent) {
      debugPrint("User Consent: $userConsent");
      if (userConsent.needConsentReview) {
        // Show Consent UI
      }
    },
  );

  Pam.allowAllTrackingConsent("xxx");
}

void main() {
  var pamConfig =
      PamConfigProvider.getDevelopConfig(identityProvider, onIdentityMismatch);
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
        debugPrint("CLICK LEARN MORE.");
        debugPrint(bannerData.toString());
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
            TextButton(
              style: ButtonStyle(
                foregroundColor: WidgetStateProperty.all<Color>(Colors.blue),
              ),
              onPressed: () {
                Pam.allowAllTrackingConsent(
                  Pam.shared.config?.trackingConsentMessageID ?? "",
                );
              },
              child: Text('Allow Consent'),
            ),
            TextButton(
              style: ButtonStyle(
                foregroundColor: WidgetStateProperty.all<Color>(Colors.blue),
              ),
              onPressed: () {
                Pam.appAttention(context, pageName: "home");
              },
              child: Text('Attention'),
            )
          ],
        ),
      ),
    );
  }
}
