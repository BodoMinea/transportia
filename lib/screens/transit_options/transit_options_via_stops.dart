import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../models/routing_options.dart';
import '../../models/transitous/enums.dart';
import '../../services/transitous_geocode_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/haptics.dart';
import '../../widgets/custom_card.dart';
import '../../widgets/section_title.dart';
import '../../widgets/options/value_controls.dart';
import '../../theme/app_text.dart';

/// Stops every journey should pass through.
///
/// Only stops can be used: the server matches `via` against a feed-prefixed
/// stop id and rejects anything else, so addresses and plain coordinates are
/// filtered out of the suggestions.
/// How long typing has to pause before a via-stop lookup is sent.
const Duration _kViaSearchDebounce = Duration(milliseconds: 300);

class TransitOptionsViaStopsCard extends StatefulWidget {
  const TransitOptionsViaStopsCard({
    super.key,
    required this.options,
    required this.onChanged,
  });

  final RoutingOptions options;
  final ValueChanged<RoutingOptions> onChanged;

  @override
  State<TransitOptionsViaStopsCard> createState() =>
      _TransitOptionsViaStopsCardState();
}

class _TransitOptionsViaStopsCardState
    extends State<TransitOptionsViaStopsCard> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  List<TransitousLocationSuggestion> _suggestions = const [];
  bool _isSearching = false;
  bool _isAdding = false;
  Timer? _debounce;

  /// Guards against an earlier, slower search overwriting a later one.
  int _requestId = 0;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    final query = value.trim();
    if (query.length < 3) {
      setState(() {
        _suggestions = const [];
        _isSearching = false;
      });
      return;
    }
    setState(() => _isSearching = true);
    _debounce = Timer(_kViaSearchDebounce, () => _search(query));
  }

  Future<void> _search(String query) async {
    final requestId = ++_requestId;
    try {
      final results = await TransitousGeocodeService.fetchSuggestions(
        text: query,
        type: LocationType.stop.wireName,
      );
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _suggestions = results.where((s) => s.match?.isStop ?? false).toList();
        _isSearching = false;
      });
    } catch (_) {
      if (!mounted || requestId != _requestId) return;
      // A failed lookup should leave the field usable, not surface an error
      // over a settings screen.
      setState(() {
        _suggestions = const [];
        _isSearching = false;
      });
    }
  }

  void _add(TransitousLocationSuggestion suggestion) {
    final stopId = suggestion.match?.id ?? suggestion.id;
    if (widget.options.via.any((v) => v.stopId == stopId)) {
      _clearSearch();
      return;
    }
    Haptics.lightTick();
    widget.onChanged(
      widget.options.copyWith(
        via: [
          ...widget.options.via,
          ViaStopOption(stopId: stopId, name: suggestion.name),
        ],
      ),
    );
    _clearSearch();
  }

  void _clearSearch() {
    _controller.clear();
    _focusNode.unfocus();
    setState(() {
      _suggestions = const [];
      _isSearching = false;
      _isAdding = false;
    });
  }

  void _remove(int index) {
    final via = [...widget.options.via]..removeAt(index);
    widget.onChanged(widget.options.copyWith(via: via));
  }

  void _setStay(int index, Duration stay) {
    final via = [...widget.options.via];
    via[index] = via[index].copyWith(minimumStay: stay);
    widget.onChanged(widget.options.copyWith(via: via));
  }

  @override
  Widget build(BuildContext context) {
    final accent = AppColors.accentOf(context);
    final via = widget.options.via;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionTitle(text: 'Via stops'),
        const SizedBox(height: 12),
        CustomCard(
          padding: const EdgeInsets.all(16),
          margin: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (via.isEmpty && !_isAdding)
                Text(
                  'Route every journey through a stop you choose.',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.black.withValues(alpha: 0.45),
                  ),
                ),
              for (var i = 0; i < via.length; i++) ...[
                if (i > 0) const SizedBox(height: 12),
                _ViaStopRow(
                  stop: via[i],
                  onRemove: () => _remove(i),
                  onStayChanged: (stay) => _setStay(i, stay),
                ),
              ],
              const SizedBox(height: 12),
              if (_isAdding)
                _buildSearchField(accent)
              else
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    setState(() => _isAdding = true);
                    _focusNode.requestFocus();
                  },
                  child: Row(
                    children: [
                      Icon(LucideIcons.plus, size: 16, color: accent),
                      const SizedBox(width: 8),
                      Text(
                        'Add via stop',
                        style: TextStyle(fontSize: 14, color: accent),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSearchField(Color accent) {
    // A stop abroad says so; one at home does not repeat the country.
    final homeCountry = View.of(context).platformDispatcher.locale.countryCode;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(LucideIcons.search, size: 16, color: accent),
            const SizedBox(width: 10),
            Expanded(
              child: CupertinoTextField.borderless(
                controller: _controller,
                focusNode: _focusNode,
                placeholder: 'Search for a stop',
                style: TextStyle(fontSize: 15, color: AppColors.black),
                placeholderStyle: TextStyle(
                  fontSize: 15,
                  color: AppColors.black.withValues(alpha: 0.3),
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
                autocorrect: false,
                onChanged: _onQueryChanged,
              ),
            ),
            GestureDetector(
              onTap: _clearSearch,
              child: Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Icon(
                  LucideIcons.x,
                  size: 16,
                  color: AppColors.black.withValues(alpha: 0.35),
                ),
              ),
            ),
          ],
        ),
        if (_isSearching)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Searching…',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.black.withValues(alpha: 0.4),
              ),
            ),
          ),
        for (final suggestion in _suggestions.take(6))
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _add(suggestion),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                children: [
                  Icon(
                    LucideIcons.trainFront,
                    size: 16,
                    color: AppColors.black.withValues(alpha: 0.45),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          suggestion.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.black,
                          ),
                        ),
                        if (suggestion.caption(homeCountry: homeCountry)
                            case final caption when caption.isNotEmpty)
                          Text(
                            caption,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.black.withValues(alpha: 0.45),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _ViaStopRow extends StatelessWidget {
  const _ViaStopRow({
    required this.stop,
    required this.onRemove,
    required this.onStayChanged,
  });

  final ViaStopOption stop;
  final VoidCallback onRemove;
  final ValueChanged<Duration> onStayChanged;

  /// Zero means "may pass through without stopping", which often yields
  /// better connections than forcing a wait.
  static const List<int> _stayChoices = [0, 5, 10, 20];

  @override
  Widget build(BuildContext context) {
    final accent = AppColors.accentOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(LucideIcons.mapPin, size: 16, color: accent),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                stop.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.listTitle,
              ),
            ),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onRemove,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                child: Icon(
                  LucideIcons.trash2,
                  size: 16,
                  color: AppColors.black.withValues(alpha: 0.35),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            for (var i = 0; i < _stayChoices.length; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              Expanded(
                child: QuickValueCard(
                  value: _stayChoices[i] == 0
                      ? 'Pass through'
                      : '${_stayChoices[i]} min',
                  selected: stop.minimumStay.inMinutes == _stayChoices[i],
                  onTap: () =>
                      onStayChanged(Duration(minutes: _stayChoices[i])),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}
