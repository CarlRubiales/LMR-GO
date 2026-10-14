import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

class AccountPage extends StatelessWidget {
  const AccountPage({super.key, required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.cream,
    appBar: AppBar(
      title: Text(
        title,
        style: GoogleFonts.playfairDisplay(
          fontSize: 20,
          color: AppColors.plum,
          fontWeight: FontWeight.w600,
        ),
      ),
      elevation: 0,
      backgroundColor: AppColors.cream,
      foregroundColor: AppColors.plum,
    ),
    body: SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          ),
        ),
      ),
    ),
  );
}

class PreviewNotice extends StatelessWidget {
  const PreviewNotice({
    super.key,
    this.text = 'Local preview · changes reset when you log out or restart.',
  });
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Text(
      text,
      style: GoogleFonts.inter(color: AppColors.muted, fontSize: 11),
    ),
  );
}

void accountFeedback(BuildContext context, String text) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      backgroundColor: AppColors.plum,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      content: Text(
        text,
        style: GoogleFonts.inter(color: AppColors.cream),
      ),
    ),
  );
}

Future<void> accountInfo(BuildContext context, String title, String text) =>
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cream,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: AppColors.line),
        ),
        title: Text(
          title,
          style: GoogleFonts.playfairDisplay(
            color: AppColors.plum,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Text(
          text,
          style: GoogleFonts.inter(color: AppColors.ink, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );

Future<bool> accountConfirm(
  BuildContext context,
  String title,
  String text,
  String action,
) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cream,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: AppColors.line),
        ),
        title: Text(
          title,
          style: GoogleFonts.playfairDisplay(
            color: AppColors.plum,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Text(
          text,
          style: GoogleFonts.inter(color: AppColors.ink, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: ['Log out', 'Remove', 'Delete'].contains(action)
                ? AppTheme.dangerButton
                : FilledButton.styleFrom(
                    backgroundColor: AppColors.plum,
                    foregroundColor: AppColors.cream,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(9),
                    ),
                  ),
            child: Text(action),
          ),
        ],
      ),
    ) ??
    false;

Widget accountDetail(String label, String value) => Card(
  color: AppColors.cream,
  elevation: 0,
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(16),
    side: const BorderSide(color: AppColors.line),
  ),
  child: ListTile(
    title: Text(
      label,
      style: GoogleFonts.inter(fontSize: 11, color: AppColors.muted),
    ),
    subtitle: Text(
      value.trim().isEmpty ? 'Not provided' : value,
      style: GoogleFonts.inter(
        color: AppColors.plum,
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
    ),
  ),
);

Future<Uint8List?> chooseAccountPhoto(BuildContext context) async {
  final source = await showModalBottomSheet<ImageSource>(
    context: context,
    showDragHandle: true,
    backgroundColor: AppColors.cream,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.photo_library_outlined, color: AppColors.orange),
            title: const Text('Choose photo'),
            onTap: () => Navigator.pop(context, ImageSource.gallery),
          ),
          ListTile(
            leading: const Icon(Icons.camera_alt_outlined, color: AppColors.orange),
            title: const Text('Take photo'),
            onTap: () => Navigator.pop(context, ImageSource.camera),
          ),
        ],
      ),
    ),
  );
  if (source == null || !context.mounted) return null;
  try {
    final photo = await ImagePicker().pickImage(
      source: source,
      maxWidth: 1800,
      maxHeight: 1800,
      imageQuality: 85,
      requestFullMetadata: false,
    );
    if (photo == null) return null;
    if (await photo.length() > 10 * 1024 * 1024) {
      if (context.mounted) {
        accountFeedback(context, 'Choose an image smaller than 10 MB.');
      }
      return null;
    }
    final bytes = await photo.readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes, targetWidth: 1800);
    codec.dispose();
    return bytes;
  } catch (_) {
    if (context.mounted) {
      accountFeedback(
        context,
        'Unable to open that photo. Check photo/camera permissions or choose another image.',
      );
    }
    return null;
  }
}

void viewAccountPhoto(BuildContext context, Uint8List image, String title) {
  Navigator.push(
    context,
    MaterialPageRoute<void>(
      builder: (context) => Scaffold(
        backgroundColor: AppColors.cream,
        appBar: AppBar(
          title: Text(
            title,
            style: GoogleFonts.playfairDisplay(
              color: AppColors.plum,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        body: SafeArea(
          child: Center(
            child: InteractiveViewer(
              minScale: .5,
              maxScale: 5,
              child: Image.memory(
                image,
                errorBuilder: (_, _, _) =>
                    const Text('Unable to display image'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
