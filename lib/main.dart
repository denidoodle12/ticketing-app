import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app.dart';
import 'core/network/connectivity_service.dart';
import 'core/utils/app_info.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Set system UI overlay style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  // Initialize connectivity service
  await ConnectivityService().initialize();

  // Initialize app info (for dynamic version)
  await AppInfo.init();

  // Initialize shared preferences
  final prefs = await SharedPreferences.getInstance();

  // Initialize secure storage
  const secureStorage = FlutterSecureStorage();

  runApp(MyApp(prefs: prefs, secureStorage: secureStorage));
}
