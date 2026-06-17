import 'package:flutter/material.dart';

class GymsListScreen extends StatelessWidget {
  const GymsListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Gyms')),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.fitness_center, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('No gyms yet', style: TextStyle(fontSize: 18, color: Colors.grey)),
            SizedBox(height: 8),
            Text('Tap + to add your first gym', style: TextStyle(color: Colors.grey)),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          // TODO: Add new gym
        },
        icon: const Icon(Icons.add),
        label: const Text('Add Gym'),
      ),
    );
  }
}
