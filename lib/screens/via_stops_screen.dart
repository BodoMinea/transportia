import 'package:flutter/widgets.dart';

import '../models/routing_options.dart';
import '../widgets/app_page_scaffold.dart';
import 'search_options/search_options_via_stops.dart';

/// Picks the stops a journey should pass through.
///
/// A screen rather than a control in the spine: choosing one means searching
/// for it, and a search field inside a section that is itself inside a search
/// card has nowhere to put its results.
class ViaStopsScreen extends StatefulWidget {
  const ViaStopsScreen({super.key, required this.options});

  final RoutingOptions options;

  @override
  State<ViaStopsScreen> createState() => _ViaStopsScreenState();
}

class _ViaStopsScreenState extends State<ViaStopsScreen> {
  late RoutingOptions _options = widget.options;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        Navigator.of(context).pop(_options);
      },
      child: AppPageScaffold(
        title: 'Travel through',
        scrollable: true,
        onBack: () => Navigator.of(context).pop(_options),
        body: SearchOptionsViaStopsCard(
          options: _options,
          onChanged: (next) => setState(() => _options = next),
        ),
      ),
    );
  }
}
