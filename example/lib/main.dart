import 'package:flutter/material.dart';
import 'package:pam_flutter/pam.dart';

import 'demo_auth_controller.dart';
import 'pam_config.dart';
import 'sdk_demo_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final auth = DemoAuthController();
  final config = PamConfigProvider.getDevelopConfig(
    auth.identityProvider,
    auth.onIdentityMismatch,
  );
  await Pam.initialize(config);

  runApp(MyApp(auth: auth));
}

class MyApp extends StatelessWidget {
  final DemoAuthController auth;
  const MyApp({super.key, required this.auth});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'PAM SDK Examples',
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF14203D)),
      useMaterial3: true,
    ),
    home: SdkDemoPage(auth: auth),
  );
}
