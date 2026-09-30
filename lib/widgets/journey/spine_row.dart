import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../../theme/journey_metrics.dart';
import 'spine_rail.dart';

/// One row of the journey spine, and the whole of its alignment contract.
///
/// Four columns, the same on every row of both screens:
///
/// | 1 | [JourneyMetrics.timeColumn], right-aligned | times and delays |
/// | 2 | [JourneyMetrics.gutter] | the rail and its node |
/// | 3 | flexible | names, badges, notes |
/// | 4 | intrinsic, right-aligned | the platform |
///
/// Before this, a leg card put its text on five different left edges — the
/// card's padding, the title after its icon, the subtitle back at the padding,
/// the endpoint rows after an arrow, and the timeline's own contents. Anything
/// that wants to sit on the spine goes through here, so there is one place
/// where those edges are decided and no way for a caller to invent a sixth.
class SpineRow extends StatelessWidget {
  const SpineRow({
    super.key,
    required this.node,
    required this.body,
    this.footer,
    this.time,
    this.meta,
    this.nodeCenter = JourneyMetrics.ring / 2,
    this.railColor,
    this.railDashed = false,
    this.railTopInset = 0,
    this.railBottomInset = 0,
    this.aboveAnchor = 0,
    this.railAboveColor,
    this.railAboveDashed = false,
    this.railTravelled = 0,
    this.railAboveTravelled = 0,
    this.firstLineHeight = 20,
    this.padding = const EdgeInsets.symmetric(
      horizontal: JourneyMetrics.screenPadding,
    ),
    this.timeColumn = JourneyMetrics.timeColumn,
    this.onTap,
  });

  /// The ring or dot that marks this row on the line.
  final Widget node;

  /// Where the node's centre sits, measured from the row's top. The text
  /// columns centre their first line on the same y, which is what makes a
  /// name look level with its own marker.
  final double nodeCenter;

  final Widget body;
  final Widget? time;
  final Widget? meta;

  /// Under the body and the meta column both, so what it holds spans the
  /// full width to the right of the line whatever the meta column takes.
  final Widget? footer;

  /// Null draws no line — a terminus, where the row is the end of the spine.
  final Color? railColor;
  final bool railDashed;

  /// A row carrying a ring insets the top by the ring's diameter, so the line
  /// begins under the node and the colour changes exactly there.
  final double railTopInset;
  final double railBottomInset;

  /// Room kept above the anchor line for what *arrives* here.
  ///
  /// The anchor is where the node, the station name and the departure all sit.
  /// An arrival belongs above them, and reserving its height in layout — not
  /// lifting it at paint time — is what stops it landing on top of the row
  /// before. Rows grow to hold it, so nothing can collide.
  final double aboveAnchor;

  /// The line arriving into this row's node, drawn across [aboveAnchor].
  ///
  /// That stretch belongs to the leg that got here, not the one leaving, so
  /// it takes the previous leg's colour. Without it the spine breaks at every
  /// node by exactly [aboveAnchor].
  final Color? railAboveColor;
  final bool railAboveDashed;

  /// How much of each stretch is behind the traveller, 0..1. See
  /// [SpineRail.travelled]; zero leaves the line drawn as it always was.
  final double railTravelled;
  final double railAboveTravelled;

  /// Height of the first line of [body], used to centre it on [nodeCenter].
  ///
  /// Passed in rather than measured: laying the columns out against the text's
  /// real height would need an intrinsic pass, and the height of an expanding
  /// leg is mid-animation exactly when that would run. Callers give the line
  /// height of their own first line — which is why the styles on the spine
  /// set an explicit `height` instead of leaving it to the font.
  final double firstLineHeight;

  final EdgeInsets padding;

  /// Width of the times column. Zero on the search screen, which plans a
  /// journey rather than reporting one and so has no times to align.
  final double timeColumn;

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final textTop = math.max(0.0, nodeCenter - firstLineHeight / 2);
    final railColor = this.railColor;

    final row = Stack(
      children: [
        // Behind the content and stretched to it. Positioned rather than a
        // stretched Row child, because that would need an IntrinsicHeight and
        // the height of an expanding leg is mid-animation exactly when it
        // would be asked for.
        if (railAboveColor case final aboveColor?)
          Positioned(
            left: padding.left + timeColumn,
            width: JourneyMetrics.gutter,
            top: 0,
            height: aboveAnchor,
            child: SpineRail(
              color: aboveColor,
              dashed: railAboveDashed,
              travelled: railAboveTravelled,
            ),
          ),
        if (railColor != null)
          Positioned(
            left: padding.left + timeColumn,
            width: JourneyMetrics.gutter,
            top: 0,
            bottom: 0,
            child: SpineRail(
              color: railColor,
              dashed: railDashed,
              topInset: railTopInset,
              bottomInset: railBottomInset,
              travelled: railTravelled,
            ),
          ),
        Padding(
          padding: padding,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (timeColumn > 0)
                SizedBox(
                  width: timeColumn,
                  child: Padding(
                    padding: EdgeInsets.only(top: textTop, right: 10),
                    child: Align(
                      alignment: Alignment.topRight,
                      child: time ?? const SizedBox.shrink(),
                    ),
                  ),
                ),
              SizedBox(
                width: JourneyMetrics.gutter,
                height: aboveAnchor + nodeCenter * 2,
                child: Padding(
                  padding: EdgeInsets.only(top: aboveAnchor),
                  child: Center(child: node),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Padding(
                            padding: EdgeInsets.only(
                              left: JourneyMetrics.gap,
                              top: textTop + aboveAnchor,
                            ),
                            child: body,
                          ),
                        ),
                        if (meta case final meta?)
                          Padding(
                            padding: EdgeInsets.only(left: 8, top: textTop),
                            child: meta,
                          ),
                      ],
                    ),
                    if (footer case final footer?)
                      Padding(
                        padding: const EdgeInsets.only(
                          left: JourneyMetrics.gap,
                        ),
                        child: footer,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );

    if (onTap == null) return row;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: row,
    );
  }
}
