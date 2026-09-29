import 'package:flutter/cupertino.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../models/rental_provider_prefs.dart';
import '../../models/transitous/rentals_response.dart';
import '../../theme/app_colors.dart';
import '../../utils/rental_provider_search.dart';
import '../../widgets/custom_card.dart';
import '../../widgets/options/icon_controls.dart';
import '../../widgets/search/street_leg_section.dart';
import '../../widgets/section_title.dart';

/// The rental providers the rider has an account with, picked by name.
///
/// A field rather than a list: the server knows a few hundred groups, and
/// most are in cities the rider will never visit.
class SearchOptionsRentalProvidersCard extends StatefulWidget {
  const SearchOptionsRentalProvidersCard({
    super.key,
    required this.prefs,
    required this.catalogue,
    required this.nearby,
    required this.onAdd,
    required this.onRemove,
    this.initialQuery = '',
  });

  final RentalProviderPrefs prefs;

  /// Every group the server lists. Null while it has never been fetched, so
  /// the field can say why it offers nothing.
  final List<RentalProviderGroup>? catalogue;

  /// Ids of the groups around the rider, offered first.
  final Set<String> nearby;

  final ValueChanged<PickedProviderGroup> onAdd;
  final ValueChanged<String> onRemove;

  /// Text already in the field, for drafts.
  final String initialQuery;

  @override
  State<SearchOptionsRentalProvidersCard> createState() =>
      _SearchOptionsRentalProvidersCardState();
}

class _SearchOptionsRentalProvidersCardState
    extends State<SearchOptionsRentalProvidersCard> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialQuery,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _pick(RentalProviderGroup group) {
    widget.onAdd(PickedProviderGroup(id: group.id, name: group.name.trim()));
    _controller.clear();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final catalogue = widget.catalogue;
    final listed = {for (final group in catalogue ?? const []) group.id};
    final suggestions = catalogue == null
        ? const <RentalProviderGroup>[]
        : suggestProviders(
            _controller.text,
            catalogue,
            picked: {for (final group in widget.prefs.groups) group.id},
            nearby: widget.nearby,
          );
    final muted = AppColors.black.withValues(alpha: 0.5);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionTitle(text: 'Rental providers'),
        const SizedBox(height: 12),
        CustomCard(
          padding: const EdgeInsets.all(16),
          margin: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildField(enabled: catalogue != null),
              for (final group in suggestions)
                _SuggestionRow(
                  group: group,
                  nearby: widget.nearby.contains(group.id),
                  onTap: () => _pick(group),
                ),
              if (widget.prefs.groups.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final group in widget.prefs.groups)
                      ModeChip(
                        label: catalogue == null || listed.contains(group.id)
                            ? group.name
                            : '${group.name} · no longer listed',
                        onRemove: () => widget.onRemove(group.id),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              Text(
                _helpText(catalogue == null),
                style: TextStyle(fontSize: 12.5, height: 1.35, color: muted),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _helpText(bool unavailable) {
    if (unavailable) {
      return 'The provider list could not be loaded. Connect to the '
          'internet to add providers.';
    }
    if (widget.prefs.groups.isEmpty) {
      return 'Add the providers you have an account with. Some companies '
          'are listed once per city, so add each one you use.';
    }
    return 'Turn “Limit to my providers” on or off under Shared vehicles '
        'when planning a trip.';
  }

  Widget _buildField({required bool enabled}) {
    final hint = AppColors.black.withValues(alpha: 0.35);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.black.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(LucideIcons.search, size: 16, color: hint),
          const SizedBox(width: 8),
          Expanded(
            child: CupertinoTextField.borderless(
              controller: _controller,
              enabled: enabled,
              placeholder: 'Add a provider',
              style: TextStyle(fontSize: 15, color: AppColors.black),
              placeholderStyle: TextStyle(fontSize: 15, color: hint),
              padding: const EdgeInsets.symmetric(vertical: 12),
              autocorrect: false,
              textInputAction: TextInputAction.search,
              onChanged: (_) => setState(() {}),
            ),
          ),
        ],
      ),
    );
  }
}

class _SuggestionRow extends StatelessWidget {
  const _SuggestionRow({
    required this.group,
    required this.nearby,
    required this.onTap,
  });

  final RentalProviderGroup group;
  final bool nearby;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = AppColors.accentOf(context);
    final vehicles = [
      for (final factor in group.formFactors)
        if (rentalFormFactorLabels[factor] case final label?) label,
    ].join(' · ');
    final details = [if (nearby) 'Near you', if (vehicles.isNotEmpty) vehicles];

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: AppColors.black.withValues(alpha: 0.06)),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    group.name.trim(),
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.black,
                    ),
                  ),
                  if (details.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      details.join(' · '),
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.black.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Icon(LucideIcons.plus, size: 18, color: accent),
          ],
        ),
      ),
    );
  }
}
