import 'package:flutter/material.dart';

class MailScreen extends StatelessWidget {
  const MailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mail'), backgroundColor: Colors.black87),
      backgroundColor: Colors.black,
      body: const Center(child: Text('Mail Screen Draft', style: TextStyle(color: Colors.white, fontSize: 24))),
    );
  }
}

