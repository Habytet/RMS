import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/token_provider.dart';

class CustomerScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final nowServing = context.watch<TokenProvider>().nowServing;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('NOW SERVING', style: TextStyle(color: Colors.white, fontSize: 30)),
            SizedBox(height: 20),
            Text(
              nowServing != null ? '$nowServing' : '-',
              style: TextStyle(color: Colors.greenAccent, fontSize: 80, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}