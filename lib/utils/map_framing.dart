import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/painting.dart' show EdgeInsets;

import 'package:maplibre_gl/maplibre_gl.dart';

import 'geo_utils.dart';

/// MapLibre's tile size: the world is this many logical pixels wide at
/// zoom 0, and doubles with every zoom level.
const double kWorldTilePixels = 512;

/// Web Mercator position of [p] in world pixels at zoom 0.
///
/// Working here rather than in degrees keeps distances as the map draws
/// them: a spread measured in these units becomes a zoom with one `log2`.
Offset worldPoint(LatLng p) {
  final x = (p.longitude + 180) / 360 * kWorldTilePixels;
  final sinLat = math.sin(p.latitude * math.pi / 180);
  final y =
      (0.5 - math.log((1 + sinLat) / (1 - sinLat)) / (4 * math.pi)) *
      kWorldTilePixels;
  return Offset(x, y);
}

/// The inverse of [worldPoint].
LatLng fromWorldPoint(Offset w) {
  final lon = w.dx / kWorldTilePixels * 360 - 180;
  final n = math.pi - 2 * math.pi * w.dy / kWorldTilePixels;
  final lat = 180 / math.pi * math.atan(0.5 * (math.exp(n) - math.exp(-n)));
  return LatLng(lat, lon);
}

/// Where the map looks, as far as placing things over it goes.
class MapView {
  const MapView({
    required this.center,
    required this.zoom,
    required this.size,
    this.bearing = 0,
  });

  final LatLng center;
  final double zoom;

  /// The map widget's size in logical pixels.
  final Size size;

  /// Degrees clockwise from north that the top of the map faces.
  final double bearing;

  double get _scale => math.pow(2, zoom).toDouble();

  /// Where [p] is drawn, in logical pixels from the map's top left.
  ///
  /// Anything off the map comes out beyond its edges, which is what the
  /// edge arrows are made from. Of the two ways round the globe, the
  /// shorter is taken, so a place across the date line is not drawn a
  /// world away.
  Offset project(LatLng p) {
    final c = worldPoint(center);
    var d = worldPoint(p) - c;
    const half = kWorldTilePixels / 2;
    if (d.dx > half) d -= const Offset(kWorldTilePixels, 0);
    if (d.dx < -half) d += const Offset(kWorldTilePixels, 0);
    d *= _scale;
    // Turning the map by the bearing turns what is on it the other way.
    final t = -bearing * math.pi / 180;
    final turned = Offset(
      d.dx * math.cos(t) - d.dy * math.sin(t),
      d.dx * math.sin(t) + d.dy * math.cos(t),
    );
    return size.center(Offset.zero) + turned;
  }
}

/// The smallest box around [points], null for none.
LatLngBounds? boundsOf(Iterable<LatLng> points) {
  if (points.isEmpty) return null;
  var south = points.first.latitude, north = south;
  var west = points.first.longitude, east = west;
  for (final p in points.skip(1)) {
    south = math.min(south, p.latitude);
    north = math.max(north, p.latitude);
    west = math.min(west, p.longitude);
    east = math.max(east, p.longitude);
  }
  return LatLngBounds(
    southwest: LatLng(south, west),
    northeast: LatLng(north, east),
  );
}

/// The middle of [bounds], in degrees.
LatLng boundsCenter(LatLngBounds bounds) => LatLng(
  (bounds.southwest.latitude + bounds.northeast.latitude) / 2,
  (bounds.southwest.longitude + bounds.northeast.longitude) / 2,
);

/// A camera to move to: the centre and zoom that show what was asked.
typedef MapFrame = ({LatLng center, double zoom});

/// Rank-weighted mean and standard deviation of [points], per axis.
///
/// One pass (West's weighted form of Welford's method), so no second walk
/// over the points and no cancellation when they sit close together.
/// Weights of zero or less are skipped. Null for no usable point.
({Offset mean, Offset sigma})? weightedSpread(
  Iterable<(Offset, double)> points,
) {
  var total = 0.0;
  var mean = Offset.zero;
  var m2x = 0.0;
  var m2y = 0.0;
  for (final (p, w) in points) {
    if (w <= 0) continue;
    total += w;
    final before = p - mean;
    mean += before * (w / total);
    final after = p - mean;
    m2x += w * before.dx * after.dx;
    m2y += w * before.dy * after.dy;
  }
  if (total == 0) return null;
  return (
    mean: mean,
    sigma: Offset(math.sqrt(m2x / total), math.sqrt(m2y / total)),
  );
}

/// How much result [rank] (0-based) counts in the framing: #1 counts 1,
/// #2 a half, #3 a third. MOTIS's order is the only relevance there is.
double rankWeight(int rank) => 1 / (rank + 1);

/// How many of the top results the opening view is decided by.
const int _kFramedResults = 10;

/// A jump in distance from #1 this large or more starts a new group.
const double _kGroupGapFactor = 4;

/// #1's group takes in further groups until it holds this share of the
/// rank weight: a lone #1 among equally good answers takes its peers along.
const double _kGroupWeightShare = 0.5;

/// Distances within this count as together. Without it #1, zero metres
/// from itself, would see every neighbour as a jump.
const double _kGroupSoftMetres = 1000;

/// How many standard deviations of the group fill the screen: the core, not
/// its stragglers, which become edge arrows instead.
const double _kFramedSigmas = 2;

/// Indices into [ranked] of the results #1 belongs with.
///
/// Sorted by distance from #1, the top results are split wherever the
/// distance jumps [_kGroupGapFactor]-fold; #1's group then grows a whole
/// group at a time until it holds [_kGroupWeightShare] of the weight.
/// Always contains 0; empty only for an empty list.
List<int> leadingGroup(List<LatLng> ranked) {
  if (ranked.isEmpty) return const [];
  final top = ranked.length < _kFramedResults ? ranked.length : _kFramedResults;
  final first = ranked.first;
  double reach(int i) =>
      coordinateDistanceInMeters(
        first.latitude,
        first.longitude,
        ranked[i].latitude,
        ranked[i].longitude,
      ) +
      _kGroupSoftMetres;

  final byDistance = List.generate(top, (i) => i)
    ..sort((a, b) => reach(a).compareTo(reach(b)));
  var totalWeight = 0.0;
  for (var i = 0; i < top; i++) {
    totalWeight += rankWeight(i);
  }

  final group = <int>[];
  var held = 0.0;
  for (var k = 0; k < byDistance.length; k++) {
    final i = byDistance[k];
    final isNewGroup =
        k > 0 && reach(i) / reach(byDistance[k - 1]) >= _kGroupGapFactor;
    final isEnough = held >= _kGroupWeightShare * totalWeight;
    if (isNewGroup && isEnough) break;
    group.add(i);
    held += rankWeight(i);
  }
  return group;
}

/// The opening view of [ranked] results: #1's group to ±2σ around its
/// rank-weighted centre, never closer than [maxZoom], #1 always inside.
///
/// Plain σ over every result is ruined by outliers (one Paris in Brazil
/// stretches it across the Atlantic), hence [leadingGroup] first. And σ,
/// not the bounding box: one straggler at the group's edge would zoom
/// everything out. Null for no results.
MapFrame? frameResults(
  List<LatLng> ranked,
  Size size, {
  required double maxZoom,
  EdgeInsets padding = EdgeInsets.zero,
}) {
  final group = leadingGroup(ranked);
  if (group.isEmpty) return null;
  final spread = weightedSpread([
    for (final i in group) (worldPoint(ranked[i]), rankWeight(i)),
  ])!;
  final first = worldPoint(ranked.first);
  final halfWidth = math.max(
    _kFramedSigmas * spread.sigma.dx,
    (first.dx - spread.mean.dx).abs(),
  );
  final halfHeight = math.max(
    _kFramedSigmas * spread.sigma.dy,
    (first.dy - spread.mean.dy).abs(),
  );
  return _fit(
    spread.mean,
    halfWidth,
    halfHeight,
    size,
    maxZoom: maxZoom,
    padding: padding,
  );
}

/// Every one of [points] on screen, never closer than [maxZoom]: for an
/// edge arrow the rider tapped, whose places they asked to see. Null for no
/// points.
MapFrame? fitAll(
  List<LatLng> points,
  Size size, {
  required double maxZoom,
  EdgeInsets padding = EdgeInsets.zero,
}) {
  if (points.isEmpty) return null;
  var box = Rect.fromCenter(
    center: worldPoint(points.first),
    width: 0,
    height: 0,
  );
  for (final p in points.skip(1)) {
    box = box.expandToInclude(
      Rect.fromCenter(center: worldPoint(p), width: 0, height: 0),
    );
  }
  return _fit(
    box.center,
    box.width / 2,
    box.height / 2,
    size,
    maxZoom: maxZoom,
    padding: padding,
  );
}

/// The zoom at which a box of half-extents [halfWidth] × [halfHeight] world
/// pixels around [center] fits inside [size] less [padding].
MapFrame _fit(
  Offset center,
  double halfWidth,
  double halfHeight,
  Size size, {
  required double maxZoom,
  required EdgeInsets padding,
}) {
  const minZoom = 0.0;
  final room = padding.deflateSize(size);
  final scales = [
    if (halfWidth > 0) room.width / (2 * halfWidth),
    if (halfHeight > 0) room.height / (2 * halfHeight),
  ];
  final zoom = scales.isEmpty
      ? maxZoom
      : (math.log(scales.reduce(math.min)) / math.ln2).clamp(minZoom, maxZoom);
  return (center: fromWorldPoint(center), zoom: zoom.toDouble());
}

/// Off-screen results pointing the same way, shown as one arrow.
class EdgeArrow {
  const EdgeArrow({
    required this.angle,
    required this.edge,
    required this.members,
  });

  /// Radians, 0 pointing right and growing clockwise, as on screen.
  final double angle;

  /// Where the arrow meets the edge of the area it was placed in.
  final Offset edge;

  /// Indices of the points it stands for.
  final List<int> members;

  bool get isSeveral => members.length > 1;
}

/// Arrows need this much between their directions to stay apart.
const double _kArrowMergeRadians = 25 * math.pi / 180;

/// Arrows along the edge of [area] for those of [points] outside it.
///
/// Points are screen positions, as [MapView.project] gives them. Sorted by
/// direction from the centre of [area], a point joins the previous arrow
/// when within 25° of it, and the last and first arrows merge across ±180°.
/// Each arrow points at the circular mean of its members, so arrows keep
/// their true direction rather than snapping to compass points.
List<EdgeArrow> edgeArrows(List<Offset> points, Rect area) {
  final centre = area.center;
  final outside = <(double, int)>[
    for (var i = 0; i < points.length; i++)
      if (!area.contains(points[i])) ((points[i] - centre).direction, i),
  ]..sort((a, b) => a.$1.compareTo(b.$1));

  final groups = <List<(double, int)>>[];
  for (final entry in outside) {
    final isNear =
        groups.isNotEmpty &&
        entry.$1 - groups.last.last.$1 < _kArrowMergeRadians;
    if (isNear) {
      groups.last.add(entry);
    } else {
      groups.add([entry]);
    }
  }
  final wrapsAround =
      groups.length > 1 &&
      groups.first.first.$1 + 2 * math.pi - groups.last.last.$1 <
          _kArrowMergeRadians;
  if (wrapsAround) groups.first.insertAll(0, groups.removeLast());

  return [
    for (final g in groups)
      () {
        final angle = math.atan2(
          g.fold<double>(0, (sum, e) => sum + math.sin(e.$1)),
          g.fold<double>(0, (sum, e) => sum + math.cos(e.$1)),
        );
        return EdgeArrow(
          angle: angle,
          edge: edgePoint(area, angle),
          members: [for (final e in g) e.$2],
        );
      }(),
  ];
}

/// Where a ray from the centre of [area] at [angle] leaves it.
Offset edgePoint(Rect area, double angle) {
  final d = Offset.fromDirection(angle);
  final c = area.center;
  final tx = d.dx == 0
      ? double.infinity
      : ((d.dx > 0 ? area.right : area.left) - c.dx) / d.dx;
  final ty = d.dy == 0
      ? double.infinity
      : ((d.dy > 0 ? area.bottom : area.top) - c.dy) / d.dy;
  return c + d * math.min(tx, ty);
}

/// The first of [candidates], as centres of a box of [size], that overlaps
/// none of [taken]; the first candidate when every one does.
///
/// A handful of rectangle checks per label, cheap enough to redo on every
/// frame of a pan.
Rect firstFreeRect(List<Offset> candidates, Size size, List<Rect> taken) {
  Rect at(Offset c) =>
      Rect.fromCenter(center: c, width: size.width, height: size.height);
  for (final c in candidates) {
    final rect = at(c);
    if (!taken.any(rect.overlaps)) return rect;
  }
  return at(candidates.first);
}
