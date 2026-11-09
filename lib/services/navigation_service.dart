import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/app_colors.dart';

class NavigationService {
  NavigationService._();

  /// Launch Turn-by-Turn GPS directions to the target address.
  /// Tries platform native intents (Google Maps navigation, Waze) first,
  /// with seamless fallback to universal web maps.
  static Future<void> navigateToAddress(
    BuildContext context, {
    required String address,
    String? name,
    String? landmark,
  }) async {
    final cleanAddress = address.trim();
    if (cleanAddress.isEmpty) return;

    // Full query including country context for precise geocoding in Philippines
    final query = cleanAddress.toLowerCase().contains('philippines')
        ? cleanAddress
        : '$cleanAddress, Philippines';

    final encodedQuery = Uri.encodeComponent(query);

    // 1. Android turn-by-turn driving navigation intent
    final androidNavigationUri = Uri.parse('google.navigation:q=$encodedQuery&mode=d');

    // 2. Universal Google Maps Directions Web/App URL (launches directions mode, not just search)
    final googleMapsDirectionsUri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$encodedQuery&travelmode=driving',
    );

    // 3. Waze turn-by-turn navigation intent
    final wazeUri = Uri.parse('waze://?q=$encodedQuery&navigate=yes');

    try {
      // First attempt native Google Maps navigation intent
      if (await canLaunchUrl(androidNavigationUri)) {
        final launched = await launchUrl(
          androidNavigationUri,
          mode: LaunchMode.externalApplication,
        );
        if (launched) return;
      }
    } catch (_) {}

    try {
      // Second attempt universal Google Maps directions URL
      if (await canLaunchUrl(googleMapsDirectionsUri)) {
        final launched = await launchUrl(
          googleMapsDirectionsUri,
          mode: LaunchMode.externalApplication,
        );
        if (launched) return;
      }
    } catch (_) {}

    // If direct intents couldn't be launched automatically, present the Navigation Sheet
    if (context.mounted) {
      showNavigationSheet(
        context,
        address: cleanAddress,
        name: name,
        landmark: landmark,
        googleMapsUri: googleMapsDirectionsUri,
        wazeUri: wazeUri,
      );
    }
  }

  /// Displays a rider-friendly Navigation Picker modal
  static void showNavigationSheet(
    BuildContext context, {
    required String address,
    String? name,
    String? landmark,
    Uri? googleMapsUri,
    Uri? wazeUri,
  }) {
    final encoded = Uri.encodeComponent(
      address.toLowerCase().contains('philippines') ? address : '$address, Philippines',
    );

    final gmapsUri = googleMapsUri ??
        Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$encoded&travelmode=driving');
    final wzUri = wazeUri ?? Uri.parse('waze://?q=$encoded&navigate=yes');

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: AppColors.cream,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.muted.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Title and Destination
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.plum,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.navigation_rounded, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name ?? 'Delivery Destination',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: AppColors.plum,
                          ),
                        ),
                        Text(
                          address,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: AppColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (landmark != null && landmark.isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.blush1,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppColors.line),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.flag_outlined, size: 13, color: AppColors.orange),
                      const SizedBox(width: 6),
                      Text(
                        'Landmark: $landmark',
                        style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.ink),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 18),
              const Divider(color: AppColors.line, height: 1),
              const SizedBox(height: 14),

              // Navigation Options
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.line),
                  ),
                  child: const Icon(Icons.map_rounded, color: Color(0xFF1E88E5), size: 22),
                ),
                title: Text(
                  'Google Maps Navigation',
                  style: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.ink),
                ),
                subtitle: Text(
                  'Turn-by-turn driving directions',
                  style: GoogleFonts.inter(fontSize: 11, color: AppColors.muted),
                ),
                trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.muted),
                onTap: () async {
                  Navigator.pop(ctx);
                  try {
                    await launchUrl(gmapsUri, mode: LaunchMode.externalApplication);
                  } catch (_) {
                    await launchUrl(gmapsUri, mode: LaunchMode.platformDefault);
                  }
                },
              ),

              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.line),
                  ),
                  child: const Icon(Icons.near_me_rounded, color: Color(0xFF00D1FF), size: 22),
                ),
                title: Text(
                  'Waze',
                  style: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.ink),
                ),
                subtitle: Text(
                  'Community real-time traffic route',
                  style: GoogleFonts.inter(fontSize: 11, color: AppColors.muted),
                ),
                trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.muted),
                onTap: () async {
                  Navigator.pop(ctx);
                  try {
                    if (await canLaunchUrl(wzUri)) {
                      await launchUrl(wzUri, mode: LaunchMode.externalApplication);
                    } else {
                      await launchUrl(gmapsUri, mode: LaunchMode.externalApplication);
                    }
                  } catch (_) {
                    await launchUrl(gmapsUri, mode: LaunchMode.platformDefault);
                  }
                },
              ),

              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.line),
                  ),
                  child: const Icon(Icons.copy_rounded, color: AppColors.plum, size: 20),
                ),
                title: Text(
                  'Copy Address',
                  style: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.ink),
                ),
                subtitle: Text(
                  'Copy destination to clipboard',
                  style: GoogleFonts.inter(fontSize: 11, color: AppColors.muted),
                ),
                trailing: const Icon(Icons.chevron_right, size: 16, color: AppColors.muted),
                onTap: () async {
                  Navigator.pop(ctx);
                  await Clipboard.setData(ClipboardData(text: address));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Address copied: $address'),
                        backgroundColor: AppColors.plum,
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
