import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../../theme/app_colors.dart';
import '../../utils/geo_utils.dart';
import '../../utils/map_framing.dart';
import '../../utils/place_caption.dart';

/// Tabs along the edge of the map pointing at results off it.
///
/// A Flutter layer over the map rather than map symbols: MapLibre only
/// draws what is in view, and these are about what is not. Positions come
/// from [MapView.project], worked out in Dart on every camera move with no
/// round trip to the map.
class EdgeTabsLayer extends StatelessWidget {
  const EdgeTabsLayer({
    super.key,
    required this.view,
    required this.targets,
    required this.area,
    required this.taken,
    required this.onTap,
  });

  final MapView view;

  /// Every result, in rank order; those on screen get no tab.
  final List<LatLng> targets;

  /// The part of the map the tabs stand at the edge of, in the map's
  /// coordinates: the map less whatever card covers its foot.
  final Rect area;

  /// Where pins and their names are drawn, so labels can step aside.
  final List<Rect> taken;

  /// With the indices of the results a tab stands for.
  final ValueChanged<List<int>> onTap;

  /// Label boxes are estimated rather than measured: a pan redraws this on
  /// every frame, and a text layout per label per frame is not worth it for
  /// deciding which side of a tab a distance goes.
  static const double _labelCharWidth = 7.5;
  static const double _labelHeight = 18;
  static const double _labelGap = 6;

  /// A tab is thinner than a finger; this is what a tap has to hit.
  static const double _hitSize = 48;

  @override
  Widget build(BuildContext context) {
    final points = [for (final t in targets) view.project(t)];
    final arrows = edgeArrows(points, area);
    final occupied = [...taken];
    final tabs = <Widget>[];
    final labels = <Widget>[];

    for (final arrow in arrows) {
      final dir = Offset.fromDirection(arrow.angle);
      final local = arrow.edge - area.topLeft;
      // The tab's own frame: centred so it reaches [EdgeTab.inward] in from
      // the edge and [EdgeTab.overhang] past it, where it is cut off.
      final tabCentre = local - dir * ((EdgeTab.inward - EdgeTab.overhang) / 2);
      tabs.add(
        Positioned(
          left: tabCentre.dx - EdgeTab.length / 2,
          top: tabCentre.dy - EdgeTab.thickness / 2,
          child: Transform.rotate(
            angle: arrow.angle,
            child: EdgeTab(several: arrow.isSeveral),
          ),
        ),
      );

      final label = formatPlaceDistance(_nearest(arrow.members));
      final labelSize = Size(_labelCharWidth * label.length + 8, _labelHeight);
      final reach =
          EdgeTab.inward +
          _labelGap +
          (dir.dx.abs() * labelSize.width + dir.dy.abs() * labelSize.height) /
              2;
      final inside = arrow.edge - dir * reach;
      final side = Offset(-dir.dy, dir.dx) * (labelSize.height + 4);
      final step = dir * (labelSize.height + _labelGap);
      final rect = firstFreeRect(
        [
          for (var k = 0; k < 4; k++) ...[
            inside - step * k.toDouble(),
            inside - step * k.toDouble() + side,
            inside - step * k.toDouble() - side,
          ],
        ],
        labelSize,
        occupied,
      );
      occupied.add(rect);

      void tap() => onTap(arrow.members);
      final hitCentre = arrow.edge - dir * (EdgeTab.inward / 2);
      labels.add(
        Positioned.fromRect(
          rect: Rect.fromCenter(
            center: hitCentre,
            width: _hitSize,
            height: _hitSize,
          ),
          child: Semantics(
            button: true,
            label: 'Show results $label away',
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: tap,
            ),
          ),
        ),
      );
      labels.add(
        Positioned.fromRect(
          rect: rect,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: tap,
            child: ExcludeSemantics(child: _EdgeLabel(label)),
          ),
        ),
      );
    }

    return Stack(
      children: [
        // Cut off where the tabs' edge is, whether the screen's or a card's.
        Positioned.fromRect(
          rect: area,
          child: ClipRect(child: Stack(children: tabs)),
        ),
        ...labels,
      ],
    );
  }

  /// How far the map would have to pan to reach the nearest of [members].
  double _nearest(List<int> members) => members
      .map(
        (i) => coordinateDistanceInMeters(
          view.center.latitude,
          view.center.longitude,
          targets[i].latitude,
          targets[i].longitude,
        ),
      )
      .reduce(math.min);
}

/// A tab reaching in from the edge towards results off it.
///
/// Drawn pointing along +x and turned into place: the rounded end faces the
/// middle of the map, the flat end runs past the edge and is cut off there.
class EdgeTab extends StatelessWidget {
  const EdgeTab({super.key, this.several = false});

  /// More than one result that way: a second tab peeks out behind.
  final bool several;

  /// How far the tab reaches in from the edge, and how far past it.
  static const double inward = 24;
  static const double overhang = 20;
  static const double length = inward + overhang;
  static const double thickness = 26;

  @override
  Widget build(BuildContext context) {
    final accent = AppColors.accentOf(context);
    return Container(
      width: length,
      height: thickness,
      padding: const EdgeInsets.only(left: 5),
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(
        color: accent,
        borderRadius: const BorderRadius.horizontal(
          left: Radius.circular(thickness / 2),
        ),
        boxShadow: [
          // An unblurred shadow is a copy of the tab: the same rounded end,
          // turning with it. Set back and to one side in a lighter accent,
          // it reads as a second tab stacked behind.
          if (several)
            BoxShadow(
              color: Color.lerp(accent, AppColors.solidWhite, 0.45)!,
              offset: const Offset(-6, 5),
            ),
          const BoxShadow(
            color: Color(0x33000000),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: const Icon(
        LucideIcons.arrowRight,
        size: 16,
        color: AppColors.solidWhite,
      ),
    );
  }
}

/// Black with a white halo, as the map writes a pin's name.
class _EdgeLabel extends StatelessWidget {
  const _EdgeLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: TextAlign.center,
      maxLines: 1,
      overflow: TextOverflow.visible,
      softWrap: false,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: AppColors.solidBlack,
        shadows: [
          Shadow(color: AppColors.solidWhite, blurRadius: 3),
          Shadow(color: AppColors.solidWhite, blurRadius: 3),
        ],
      ),
    );
  }
}
