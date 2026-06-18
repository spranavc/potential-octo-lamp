import 'package:flutter/material.dart';

import '../../../data/database/database.dart';

class GymCard extends StatelessWidget {
  const GymCard({super.key, required this.gym, this.onTap});

  final Gym gym;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const Icon(Icons.fitness_center),
        title: Text(gym.name),
        subtitle: const Text('Tap to view details'),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
