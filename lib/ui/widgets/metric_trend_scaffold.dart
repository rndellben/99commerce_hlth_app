import 'package:flutter/material.dart';
import 'package:hlth_app/ui/theme/app_colors.dart';

/// Shared scaffold for every metric trend-view screen.
///
/// Handles:
///   - AppBar: back button · metric name (centred) ·
///       ellipsis (•••) when [allowAddEdit] is true, info icon otherwise
///   - Info drawer — bottom sheet with [aboutTitle] / [aboutText]
///   - Ellipsis drawer — Add / Edit / Learn more / Show measurement details
///   - Any extra [actions] (e.g. sync/refresh button) rendered left of the
///       primary right icon
///
/// The actual scrollable content (chart, tiles, etc.) goes in [body].
class MetricTrendScaffold extends StatelessWidget {
  const MetricTrendScaffold({
    super.key,
    required this.metricName,
    required this.body,
    this.allowAddEdit = false,
    this.aboutTitle,
    this.aboutText,
    this.onAdd,
    this.onEdit,
    this.onShowDetails,
    this.extraActions = const [],
  });

  /// Name shown in the AppBar title.
  final String metricName;

  /// The scrollable metric content (chart + tiles + sections).
  final Widget body;

  /// When true the AppBar shows an ellipsis (•••) that opens the
  /// Add / Edit drawer. When false it shows an info (ℹ) icon that
  /// opens the About drawer.
  final bool allowAddEdit;

  /// Title shown inside the info / about drawer.
  final String? aboutTitle;

  /// Body text shown inside the info / about drawer.
  final String? aboutText;

  /// Called when the user taps "Add" in the ellipsis drawer.
  final VoidCallback? onAdd;

  /// Called when the user taps "Edit" in the ellipsis drawer.
  final VoidCallback? onEdit;

  /// Called when the user taps "Show measurement details" in the ellipsis
  /// drawer (routes to data-details screen).
  final VoidCallback? onShowDetails;

  /// Extra AppBar actions rendered before the primary icon (e.g. sync).
  final List<Widget> extraActions;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: Text(metricName),
        centerTitle: true,
        leading: const BackButton(),
        actions: [
          ...extraActions,
          if (allowAddEdit)
            IconButton(
              icon: const Icon(Icons.more_horiz),
              tooltip: 'Options',
              onPressed: () => _showEllipsisDrawer(context),
            )
          else
            IconButton(
              icon: const Icon(Icons.info_outline),
              tooltip: 'About $metricName',
              onPressed: () => _showInfoDrawer(context),
            ),
        ],
      ),
      body: body,
    );
  }

  // ── Info drawer ────────────────────────────────────────────────────────────

  void _showInfoDrawer(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _InfoDrawer(
        title: aboutTitle ?? metricName,
        text: aboutText ??
            'No additional information is available for this metric.',
      ),
    );
  }

  // ── Ellipsis drawer ────────────────────────────────────────────────────────

  void _showEllipsisDrawer(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _EllipsisDrawer(
        metricName: metricName,
        aboutTitle: aboutTitle ?? metricName,
        aboutText: aboutText ??
            'No additional information is available for this metric.',
        onAdd: onAdd,
        onEdit: onEdit,
        onShowDetails: onShowDetails,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Info drawer (metric does not allow add/edit)
// ─────────────────────────────────────────────────────────────────────────────

class _InfoDrawer extends StatelessWidget {
  const _InfoDrawer({required this.title, required this.text});
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 12),
            Text(
              text,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.5,
                  ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Ellipsis drawer (metric allows add/edit)
// ─────────────────────────────────────────────────────────────────────────────

class _EllipsisDrawer extends StatelessWidget {
  const _EllipsisDrawer({
    required this.metricName,
    required this.aboutTitle,
    required this.aboutText,
    this.onAdd,
    this.onEdit,
    this.onShowDetails,
  });

  final String metricName;
  final String aboutTitle;
  final String aboutText;
  final VoidCallback? onAdd;
  final VoidCallback? onEdit;
  final VoidCallback? onShowDetails;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(0, 12, 0, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 8),
            _DrawerItem(
              icon: Icons.add_circle_outline,
              label: 'Add',
              onTap: () {
                Navigator.pop(context);
                onAdd?.call();
              },
            ),
            _DrawerItem(
              icon: Icons.edit_outlined,
              label: 'Edit',
              onTap: () {
                Navigator.pop(context);
                onEdit?.call();
              },
            ),
            const Divider(color: AppColors.divider, height: 1),
            _DrawerItem(
              icon: Icons.info_outline,
              label: 'Learn more',
              onTap: () {
                Navigator.pop(context);
                showModalBottomSheet(
                  context: context,
                  backgroundColor: AppColors.surface,
                  shape: const RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  builder: (_) =>
                      _InfoDrawer(title: aboutTitle, text: aboutText),
                );
              },
            ),
            _DrawerItem(
              icon: Icons.bar_chart_outlined,
              label: 'Show measurement details',
              onTap: () {
                Navigator.pop(context);
                onShowDetails?.call();
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  const _DrawerItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: AppColors.textSecondary),
      title: Text(label,
          style: Theme.of(context)
              .textTheme
              .bodyLarge
              ?.copyWith(color: AppColors.textPrimary)),
      onTap: onTap,
    );
  }
}
