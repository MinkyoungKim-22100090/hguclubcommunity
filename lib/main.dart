import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'app.dart';
import 'firebase_options.dart';

bool isFirebaseInitialized() {
  return Firebase.apps.isNotEmpty && Firebase.app().name == '[DEFAULT]';
}

void main() async {
  // Ensure Flutter bindings are initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Check if Firebase app named "[DEFAULT]" is already initialized
  if (!isFirebaseInitialized()) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }

  runApp(const HGUclubCommunity());
}
