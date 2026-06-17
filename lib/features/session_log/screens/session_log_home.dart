import 'package:flutter/material.dart';

class SessionLogHome extends StatelessWidget {
  const SessionLogHome({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Session Log')),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.sports_kabaddi, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('No sessions yet', style: TextStyle(fontSize: 18, color: Colors.grey)),
            SizedBox(height: 8),
            Text('Tap + to start a new session', style: TextStyle(color: Colors.grey)),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          // TODO: Start new session
        },
        icon: const Icon(Icons.add),
        label: const Text('New Session'),
      ),
    );
  }
}
