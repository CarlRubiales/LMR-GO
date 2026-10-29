import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/psgc_service.dart';
import '../theme/app_colors.dart';

/// Searchable address picker field matching Lumora Logistics visual style.
/// Implements full search filtering, keyboard handling, empty states,
/// loading states, and disabled parent-child rules.
class SearchableAddressPicker extends StatelessWidget {
  final String label;
  final String hint;
  final PsgcLocation? selectedLocation;
  final List<PsgcLocation> items;
  final bool isEnabled;
  final bool isLoading;
  final String? disabledReason;
  final String? errorMessage;
  final VoidCallback? onRetry;
  final ValueChanged<PsgcLocation> onSelected;

  const SearchableAddressPicker({
    super.key,
    required this.label,
    required this.hint,
    required this.selectedLocation,
    required this.items,
    this.isEnabled = true,
    this.isLoading = false,
    this.disabledReason,
    this.errorMessage,
    this.onRetry,
    required this.onSelected,
  });

  void _openSearchSheet(BuildContext context) {
    if (!isEnabled || isLoading) return;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetContext) {
        return _AddressSearchSheet(
          title: label.replaceAll(' *', ''),
          selectedLocation: selectedLocation,
          items: items,
          isLoading: isLoading,
          errorMessage: errorMessage,
          onRetry: onRetry,
          onSelected: (loc) {
            Navigator.of(bottomSheetContext).pop();
            onSelected(loc);
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasSelection = selectedLocation != null;
    final isFieldInteractive = isEnabled && !isLoading;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isEnabled ? AppColors.plum : AppColors.muted,
                  ),
                ),
              ),
              if (isLoading)
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.orange,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 7),
          InkWell(
            onTap: isFieldInteractive ? () => _openSearchSheet(context) : null,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: isEnabled ? Colors.white : AppColors.blush1.withOpacity(0.5),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: errorMessage != null
                      ? AppColors.errorBoxBorder
                      : (isEnabled ? AppColors.inputBorder : AppColors.line),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      hasSelection ? selectedLocation!.name : hint,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: hasSelection
                            ? AppColors.plum
                            : (isEnabled ? AppColors.muted : AppColors.muted.withOpacity(0.7)),
                        fontWeight: hasSelection ? FontWeight.w600 : FontWeight.normal,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.keyboard_arrow_down,
                    color: isEnabled ? AppColors.plum : AppColors.muted.withOpacity(0.6),
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
          if (!isEnabled && disabledReason != null) ...[
            const SizedBox(height: 4),
            Text(
              disabledReason!,
              style: GoogleFonts.inter(
                fontSize: 11.5,
                color: AppColors.muted,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
          if (errorMessage != null) ...[
            const SizedBox(height: 5),
            Row(
              children: [
                Expanded(
                  child: Text(
                    errorMessage!,
                    style: GoogleFonts.inter(
                      fontSize: 11.5,
                      color: AppColors.errorBoxText,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                if (onRetry != null)
                  InkWell(
                    onTap: onRetry,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      child: Text(
                        'Retry',
                        style: GoogleFonts.inter(
                          fontSize: 11.5,
                          color: AppColors.orange,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _AddressSearchSheet extends StatefulWidget {
  final String title;
  final PsgcLocation? selectedLocation;
  final List<PsgcLocation> items;
  final bool isLoading;
  final String? errorMessage;
  final VoidCallback? onRetry;
  final ValueChanged<PsgcLocation> onSelected;

  const _AddressSearchSheet({
    required this.title,
    required this.selectedLocation,
    required this.items,
    required this.isLoading,
    this.errorMessage,
    this.onRetry,
    required this.onSelected,
  });

  @override
  State<_AddressSearchSheet> createState() => _AddressSearchSheetState();
}

class _AddressSearchSheetState extends State<_AddressSearchSheet> {
  final TextEditingController _searchController = TextEditingController();
  List<PsgcLocation> _filteredItems = [];

  @override
  void initState() {
    super.initState();
    _filteredItems = widget.items;
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void didUpdateWidget(covariant _AddressSearchSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.items != widget.items) {
      _applyFilter(_searchController.text);
    }
  }

  void _onSearchChanged() {
    _applyFilter(_searchController.text);
  }

  void _applyFilter(String query) {
    final q = query.trim().toLowerCase();
    setState(() {
      if (q.isEmpty) {
        _filteredItems = widget.items;
      } else {
        _filteredItems = widget.items.where((loc) {
          return loc.name.toLowerCase().contains(q);
        }).toList();
      }
    });
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);

    return Container(
      height: mediaQuery.size.height * 0.78,
      decoration: const BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: mediaQuery.viewInsets.bottom,
      ),
      child: Column(
        children: [
          // Drag handle bar
          Center(
            child: Container(
              width: 44,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              decoration: BoxDecoration(
                color: AppColors.muted.withOpacity(0.35),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Select ${widget.title}',
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 19,
                      fontWeight: FontWeight.w700,
                      color: AppColors.plum,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: AppColors.plum, size: 22),
                  onPressed: () => Navigator.of(context).pop(),
                  tooltip: 'Close',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),

          // Search input bar
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
            child: TextField(
              controller: _searchController,
              autofocus: true,
              style: GoogleFonts.inter(fontSize: 14, color: AppColors.plum),
              decoration: InputDecoration(
                hintText: 'Search ${widget.title.toLowerCase()}...',
                hintStyle: GoogleFonts.inter(fontSize: 14, color: AppColors.muted),
                prefixIcon: const Icon(Icons.search, color: AppColors.plum, size: 20),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18, color: AppColors.muted),
                        onPressed: () {
                          _searchController.clear();
                        },
                      )
                    : null,
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.inputBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.inputBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.plum, width: 1.5),
                ),
              ),
            ),
          ),

          const Divider(height: 1, thickness: 1, color: AppColors.line),

          // List content
          Expanded(
            child: _buildListContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildListContent() {
    if (widget.isLoading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: AppColors.plum, strokeWidth: 2.5),
            const SizedBox(height: 14),
            Text(
              'Loading locations...',
              style: GoogleFonts.inter(fontSize: 13, color: AppColors.muted),
            ),
          ],
        ),
      );
    }

    if (widget.errorMessage != null && widget.items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_outlined, size: 40, color: AppColors.errorBoxBorder),
              const SizedBox(height: 12),
              Text(
                widget.errorMessage!,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(fontSize: 13, color: AppColors.errorBoxText),
              ),
              if (widget.onRetry != null) ...[
                const SizedBox(height: 14),
                ElevatedButton.icon(
                  onPressed: widget.onRetry,
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('Try Again'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.plum,
                    foregroundColor: AppColors.cream,
                    textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    if (_filteredItems.isEmpty) {
      final query = _searchController.text.trim();
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.search_off_rounded, size: 44, color: AppColors.muted),
              const SizedBox(height: 12),
              Text(
                'No matching locations found',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.plum,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                query.isNotEmpty
                    ? 'No results found for "$query". Try typing another spelling.'
                    : 'No locations available in this area.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: AppColors.muted,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _filteredItems.length,
      separatorBuilder: (_, __) => const Divider(
        height: 1,
        indent: 20,
        endIndent: 20,
        color: AppColors.line,
      ),
      itemBuilder: (context, index) {
        final item = _filteredItems[index];
        final isSelected = widget.selectedLocation == item;

        return Material(
          color: isSelected ? AppColors.blush1 : Colors.transparent,
          child: InkWell(
            onTap: () => widget.onSelected(item),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      item.name,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                        color: isSelected ? AppColors.plum : AppColors.ink,
                      ),
                    ),
                  ),
                  if (isSelected)
                    const Icon(
                      Icons.check_circle_rounded,
                      color: AppColors.plum,
                      size: 20,
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
