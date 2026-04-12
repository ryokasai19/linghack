import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // for kIsWeb
import 'package:provider/provider.dart';
import 'services/user_repository.dart';
import 'screens/web_login_screen.dart';
// import 'screens/home_screen.dart'; // Use your existing Home Screen file

class AuthGate extends StatelessWidget {
  final Widget child; // The actual App (Home Screen)

  const AuthGate({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Consumer<UserRepository>(
      builder: (context, userRepo, _) {
        
        // RULE 1: If on Web AND Not Logged In -> Show Login Page
        if (kIsWeb && userRepo.user == null) {
          return const WebLoginScreen();
        }

        // RULE 2: Otherwise (Mobile OR Logged In) -> Show the App
        return child;
      },
    );
  }
}