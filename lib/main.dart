import 'package:flutter/material.dart';
import 'package:my_profile_app/screens/welcome_screen.dart';
import 'package:my_profile_app/screens/profile_screen.dart'; // Import ProfileScreen
import 'package:shared_preferences/shared_preferences.dart';
import 'package:my_profile_app/theme/theme.dart';

void main() async {
  WidgetsFlutterBinding
      .ensureInitialized(); // Ensures that the Flutter bindings are initialized before running the app
  final prefs = await SharedPreferences.getInstance();
  final token =
      prefs.getString('token'); // Get the token from shared preferences

  runApp(MyApp(token: token)); // Pass token to MyApp
}

class MyApp extends StatelessWidget {
  final String? token;

  const MyApp({super.key, this.token});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: lightMode,
      home: token != null
          ? const ProfileScreen()
          : const WelcomeScreen(), // Navigate based on token
    );
  }
}
