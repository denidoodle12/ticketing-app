import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app.dart';
import 'core/network/connectivity_service.dart';

Future<void> main() async { 
  WidgetsFlutterBinding.ensureInitialized();

  // Set system UI overlay style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  // Initialize connectivity service
  await ConnectivityService().initialize();

  // Initialize shared preferences
  final prefs = await SharedPreferences.getInstance();

  // Initialize secure storage
  const secureStorage = FlutterSecureStorage();

  runApp(MyApp(
    prefs: prefs,
    secureStorage: secureStorage,
  ));
}

