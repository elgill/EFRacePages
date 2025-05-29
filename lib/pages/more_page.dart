import 'package:flutter/material.dart';

class MorePage extends StatelessWidget {
  final String raceId;
  final Function(int) onNavigateToPage;

  const MorePage({
    Key? key,
    required this.raceId,
    required this.onNavigateToPage,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16.0),
            child: Text(
              'More Options',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          _buildOptionCard(
            context,
            icon: Icons.event_note,
            title: 'Bib Reserve',
            subtitle: 'Reserve your bib number',
            onTap: () => onNavigateToPage(5), // Page index 5
          ),
          const SizedBox(height: 12),
          _buildOptionCard(
            context,
            icon: Icons.router,
            title: 'Reader Status',
            subtitle: 'Check timing equipment status',
            onTap: () => onNavigateToPage(6), // Page index 6
          ),
          const SizedBox(height: 12),
          _buildOptionCard(
            context,
            icon: Icons.event_available,
            title: 'Event Recap',
            subtitle: 'View event recaps and highlights',
            onTap: () => onNavigateToPage(7), // Page index 7
          ),
        ],
      ),
    );
  }

  Widget _buildOptionCard(
      BuildContext context, {
        required IconData icon,
        required String title,
        required String subtitle,
        required VoidCallback onTap,
      }) {
    return Card(
      elevation: 2,
      child: ListTile(
        leading: Icon(
          icon,
          size: 32,
          color: Theme.of(context).primaryColor,
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.arrow_forward_ios),
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
      ),
    );
  }
}