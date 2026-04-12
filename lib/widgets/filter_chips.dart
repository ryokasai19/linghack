import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/language_provider.dart';

class FilterChips extends StatelessWidget {
  const FilterChips({super.key});

  @override
Widget build(BuildContext context) {
  final provider = Provider.of<LanguageProvider>(context);

  return LayoutBuilder(
    builder: (context, constraints) {
      // 1. Check if we are on Mobile (width < 600)
      bool isMobile = constraints.maxWidth < 600;

      return Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        color: Colors.transparent,
        width: double.infinity,
        // 2. Make it scrollable for mobile only
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          // Disable scrolling on PC to keep the "Fixed" feel 
          physics: isMobile ? const BouncingScrollPhysics() : const NeverScrollableScrollPhysics(),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              _buildTab(context, provider, 'All', 'all', isMobile),
              SizedBox(width: isMobile ? 6 : 12), // Smaller gaps on mobile
              _buildTab(context, provider, 'Marked', 'memorized', isMobile, icon: Icons.check_circle),
              SizedBox(width: isMobile ? 6 : 12),
              _buildTab(context, provider, 'Unmarked', 'not_memorized', isMobile, icon: Icons.radio_button_unchecked),
              SizedBox(width: isMobile ? 6 : 12),
              _buildTab(context, provider, 'All Lists', 'playlists_view', isMobile, icon: Icons.grid_view_rounded),
              
            ],
          ),
        ),
      );
    },
  );
}

  Widget _buildTab(BuildContext context, LanguageProvider provider, String label, String value, bool isMobile, {IconData? icon, VoidCallback? onTap}) {
  bool isSelected;
  if (value == 'memorized' || value == 'not_memorized') {
    isSelected = provider.memorizedFilter == value;
  } else {
    isSelected = provider.filterStatus == value;
  }
  
  return GestureDetector(
    onTap: () {
      if (onTap != null) return onTap!(); // Used by Playlist Cards
      
      // All the logic goes INSIDE these brackets
      if (value == 'memorized' || value == 'not_memorized') {
        provider.setMemorizedFilter(isSelected ? 'all' : value);
      } else {
        provider.setFilterStatus(value);
        if (value == 'all') provider.setMemorizedFilter('all');
      }
    },
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      // Smaller padding for mobile
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 10 : 15, 
        vertical: isMobile ? 6 : 10
      ),
      decoration: BoxDecoration(
        color: isSelected ? Colors.blueGrey.shade900 : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isSelected ? Colors.transparent : Colors.blueGrey.shade100,
          width: 1.5
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(
              icon, 
              size: isMobile ? 16 : 18, // Smaller icon for mobile
              color: isSelected ? Colors.tealAccent.shade400 : Colors.blueGrey.shade300
            ),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.blueGrey.shade800,
              fontWeight: FontWeight.bold,
              fontSize: isMobile ? 13 : 15, // Smaller text for mobile
            ),
          ),
        ],
      ),
    ),
  );
}
}