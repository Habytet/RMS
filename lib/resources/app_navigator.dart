import 'package:flutter/material.dart';
import 'package:token_manager/screens/login_screen.dart';

class AppNavigator {
  static void toLogout({required BuildContext context}) {
    Route route = MaterialPageRoute(
      builder: (context) => const LoginScreen(),
    );
    Navigator.pushReplacement(context, route);
  }

  static void toReplace({
    required BuildContext context,
    Widget? widget,
    String? routeName,
  }) {
    if (widget != null) {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (context, animation1, animation2) => widget,
          transitionDuration: Duration.zero,
          reverseTransitionDuration: Duration.zero,
        ),
      );
    } else if (routeName != null) {
      Navigator.of(context).pushReplacementNamed(routeName);
    } else {
      print('Please choose any route option');
    }
  }

  static void toPush({
    required BuildContext context,
    Widget? widget,
    String? routeName,
    Object? arguments,
  }) {
    if (widget != null) {
      Navigator.of(context).push(
        PageRouteBuilder(
          pageBuilder: (context, animation1, animation2) => widget,
          transitionDuration: Duration.zero,
          reverseTransitionDuration: Duration.zero,
        ),
      );
    } else if (routeName != null) {
      Navigator.of(context).pushNamed(routeName, arguments: arguments);
    } else {
      print('Please choose any route option');
    }
  }

  static void dismiss({required BuildContext context}) {
    Navigator.of(context).pop();
  }

  static void dismissUntil({
    required BuildContext context,
    required int count,
  }) {
    int internalCount = 0;
    Navigator.of(context).popUntil((route) {
      return internalCount++ == count;
    });
  }
}
