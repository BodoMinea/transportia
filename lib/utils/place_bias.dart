/// How strongly the place search leans towards where the rider is, and the
/// slider that sets it.
///
/// The value goes to `/geocode` as `placeBias`. Zero is not sent as zero: it
/// means off, and the search then carries no position at all.
class PlaceBias {
  const PlaceBias._();

  /// Chosen by measuring, not by feel; see docs/geocode-place-bias.md before
  /// changing it.
  static const double defaultValue = 1.5;

  /// Stored for "do not send my position".
  static const double off = 0;

  /// Distance between two slider stops.
  static const double step = 0.5;

  /// The strongest bias offered. At 5 a nearby shop named "Paris" already
  /// outranks the city, so anything beyond only makes that worse.
  static const double max = 5;

  /// Slider stops after the off position.
  static const int positions = 10;

  static bool isOff(double value) => value <= off;

  static bool isDefault(double value) =>
      (value - defaultValue).abs() < step / 2;

  /// The slider stop for [value]; stop 0 is off.
  static int toPosition(double value) {
    if (isOff(value)) return 0;
    return (value / step).round().clamp(1, positions);
  }

  static double fromPosition(int position) {
    if (position <= 0) return off;
    return position.clamp(1, positions) * step;
  }
}
