import 'package:flutter/cupertino.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../theme/app_colors.dart';
import '../../utils/haptics.dart';

/// Names an icon-only control on long press, hover or keyboard focus.
///
/// Icon-only controls save a lot of room, but only if the name is reachable
/// when it is needed. `Tooltip` alone would leave keyboard users without it
/// and would not survive the layout shifting underneath the finger, so this
/// exposes an explicit controller the host dismisses on any state change.
class OptionTooltipController extends ChangeNotifier {
  _TooltipRequest? _request;

  _TooltipRequest? get request => _request;

  void show(String label, Rect anchor) {
    _request = _TooltipRequest(label, anchor);
    notifyListeners();
  }

  void hide() {
    if (_request == null) return;
    _request = null;
    notifyListeners();
  }
}

class _TooltipRequest {
  const _TooltipRequest(this.label, this.anchor);
  final String label;
  final Rect anchor;
}

/// Paints the tooltip and the confirmation message over its child.
///
/// Both are positioned against this overlay's box, so the caller wraps the
/// card once and every control inside can raise one.
class OptionOverlayHost extends StatefulWidget {
  const OptionOverlayHost({
    super.key,
    required this.controller,
    required this.child,
    this.announcement,
  });

  final OptionTooltipController controller;
  final Widget child;

  /// What just changed, shown briefly at the top so it clears the action bars
  /// at the bottom of the card whatever height they take.
  final OptionAnnouncement? announcement;

  @override
  State<OptionOverlayHost> createState() => _OptionOverlayHostState();
}

class _OptionOverlayHostState extends State<OptionOverlayHost> {
  final GlobalKey _boxKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    return Stack(
      key: _boxKey,
      clipBehavior: Clip.none,
      children: [
        widget.child,
        ListenableBuilder(
          listenable: widget.controller,
          builder: (context, _) {
            final request = widget.controller.request;
            if (request == null) return const SizedBox.shrink();
            final box =
                _boxKey.currentContext?.findRenderObject() as RenderBox?;
            if (box == null) return const SizedBox.shrink();
            final origin = box.localToGlobal(Offset.zero);
            final anchor = request.anchor.shift(-origin);
            return Positioned(
              left: anchor.center.dx,
              top: anchor.top - 30,
              child: FractionalTranslation(
                translation: const Offset(-0.5, 0),
                child: _Bubble(text: request.label, compact: true),
              ),
            );
          },
        ),
        if (widget.announcement != null)
          Positioned(
            top: 8,
            left: 0,
            right: 0,
            child: Center(child: _AnnouncementBubble(widget.announcement!)),
          ),
      ],
    );
  }
}

/// A message naming what a tap just did.
class OptionAnnouncement {
  const OptionAnnouncement(this.text, {this.icon});

  final String text;
  final IconData? icon;
}

class _AnnouncementBubble extends StatelessWidget {
  const _AnnouncementBubble(this.announcement);

  final OptionAnnouncement announcement;

  @override
  Widget build(BuildContext context) {
    return _Bubble(
      text: announcement.text,
      icon: announcement.icon,
      compact: false,
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.text, required this.compact, this.icon});

  final String text;
  final bool compact;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        padding: compact
            ? const EdgeInsets.symmetric(horizontal: 9, vertical: 5)
            : const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.black,
          borderRadius: BorderRadius.circular(compact ? 7 : 999),
          boxShadow: const [
            BoxShadow(
              color: Color(0x40000000),
              blurRadius: 16,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: AppColors.white),
              const SizedBox(width: 7),
            ],
            // Bounded rather than flexible: a tooltip is positioned from one
            // edge, so its row has no width to divide up. Naming a whole
            // transport selection runs long either way, and wrapping beats
            // spilling off the card.
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 230),
              child: Text(
                text,
                style: TextStyle(
                  fontSize: compact ? 11.5 : 12.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A square icon-only button that names itself on long press.
class IconPick extends StatefulWidget {
  const IconPick({
    super.key,
    required IconData this.icon,
    required this.label,
    required this.selected,
    required this.onPressed,
    required this.tooltips,
    this.partial = false,
    this.size = 17,
  }) : glyph = null,
       _height = 40;

  /// For the traveller strip, which sits right under the origin and time and
  /// should not outweigh them.
  const IconPick.compact({
    super.key,
    required IconData this.icon,
    required this.label,
    required this.selected,
    required this.onPressed,
    required this.tooltips,
    this.size = 15,
  }) : glyph = null,
       partial = false,
       _height = 34;

  /// A mark that is not an icon, such as a letter. It takes the colour and
  /// size an icon would.
  const IconPick.glyph({
    super.key,
    required Widget this.glyph,
    required this.label,
    required this.selected,
    required this.onPressed,
    required this.tooltips,
    this.partial = false,
    this.size = 17,
  }) : icon = null,
       _height = 40;

  final double _height;

  final IconData? icon;
  final Widget? glyph;

  /// Shown on long press, announced on tap, and read out by screen readers.
  final String label;

  final bool selected;
  final VoidCallback onPressed;
  final OptionTooltipController tooltips;

  /// Stands for a set of which only some is on: drawn with a broken border
  /// and a fainter wash, between off and [selected].
  final bool partial;

  final double size;

  @override
  State<IconPick> createState() => _IconPickState();
}

class _IconPickState extends State<IconPick> {
  final GlobalKey _key = GlobalKey();

  static const double _radius = 10;

  void _showTooltip() {
    final box = _key.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    widget.tooltips.show(
      widget.label,
      box.localToGlobal(Offset.zero) & box.size,
    );
  }

  @override
  Widget build(BuildContext context) {
    final accent = AppColors.accentOf(context);
    final lit = widget.selected || widget.partial;
    final markColor = lit ? accent : AppColors.black;
    final mark = IconTheme(
      data: IconThemeData(size: widget.size, color: markColor),
      child: DefaultTextStyle.merge(
        style: TextStyle(color: markColor),
        child: widget.glyph ?? Icon(widget.icon),
      ),
    );
    final Widget face;
    if (widget.partial && !widget.selected) {
      face = CustomPaint(
        foregroundPainter: _DashedRoundedBorder(color: accent, radius: _radius),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          height: widget._height,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(_radius),
          ),
          child: Center(child: mark),
        ),
      );
    } else {
      face = AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        height: widget._height,
        decoration: BoxDecoration(
          color: widget.selected
              ? AppColors.accentWash(accent)
              : const Color(0x00000000),
          borderRadius: BorderRadius.circular(_radius),
          border: Border.all(
            color: widget.selected
                ? accent
                : AppColors.black.withValues(alpha: 0.12),
          ),
        ),
        child: Center(child: mark),
      );
    }
    return Semantics(
      button: true,
      selected: widget.selected,
      value: widget.partial && !widget.selected ? 'Partly on' : null,
      label: widget.label,
      child: GestureDetector(
        key: _key,
        behavior: HitTestBehavior.opaque,
        onTap: () {
          widget.tooltips.hide();
          Haptics.lightTick();
          widget.onPressed();
        },
        onLongPress: () {
          Haptics.lightTick();
          _showTooltip();
        },
        onLongPressEnd: (_) => widget.tooltips.hide(),
        onLongPressCancel: widget.tooltips.hide,
        child: face,
      ),
    );
  }
}

/// A rounded border drawn in dashes.
class _DashedRoundedBorder extends CustomPainter {
  const _DashedRoundedBorder({required this.color, required this.radius});

  final Color color;
  final double radius;

  static const double _dash = 4;
  static const double _gap = 3;
  static const double _stroke = 1.2;

  @override
  void paint(Canvas canvas, Size size) {
    final outline = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Offset.zero & size,
          Radius.circular(radius),
        ).deflate(_stroke / 2),
      );
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = _stroke;
    for (final metric in outline.computeMetrics()) {
      for (var d = 0.0; d < metric.length; d += _dash + _gap) {
        canvas.drawPath(metric.extractPath(d, d + _dash), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DashedRoundedBorder old) =>
      old.color != color || old.radius != radius;
}

/// An icon with a value beside it, opening a slider when pressed.
///
/// Used where a number matters but a row of preset buttons would eat the
/// width: the budget in minutes, and the transfer limit.
class ValueChip extends StatefulWidget {
  const ValueChip({
    super.key,
    required this.icon,
    required this.label,
    required this.tooltips,
    required this.onPressed,
    required this.expanded,
    this.value,
    this.valueIcon,
  });

  final IconData icon;
  final String label;
  final OptionTooltipController tooltips;
  final VoidCallback onPressed;
  final bool expanded;

  /// The number shown beside the icon. Null when [valueIcon] stands in for it.
  final String? value;

  /// Replaces [value] where a glyph says it better, e.g. unlimited.
  final IconData? valueIcon;

  @override
  State<ValueChip> createState() => _ValueChipState();
}

class _ValueChipState extends State<ValueChip> {
  final GlobalKey _key = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final accent = AppColors.accentOf(context);
    final active = widget.expanded;
    return Semantics(
      button: true,
      expanded: widget.expanded,
      label: '${widget.label} ${widget.value ?? ''}'.trim(),
      child: GestureDetector(
        key: _key,
        behavior: HitTestBehavior.opaque,
        onTap: () {
          widget.tooltips.hide();
          Haptics.lightTick();
          widget.onPressed();
        },
        onLongPress: () {
          final box = _key.currentContext?.findRenderObject() as RenderBox?;
          if (box == null) return;
          Haptics.lightTick();
          widget.tooltips.show(
            widget.label,
            box.localToGlobal(Offset.zero) & box.size,
          );
        },
        onLongPressEnd: (_) => widget.tooltips.hide(),
        onLongPressCancel: widget.tooltips.hide,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: active ? accent : AppColors.black.withValues(alpha: 0.12),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                widget.icon,
                size: 15,
                color: active ? accent : AppColors.black,
              ),
              const SizedBox(width: 6),
              if (widget.valueIcon != null)
                Icon(
                  widget.valueIcon,
                  size: 14,
                  color: active ? accent : AppColors.black,
                )
              else
                Text(
                  widget.value ?? '',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: active ? accent : AppColors.black,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A named mode picked from the dropdown, shown beside the icons so the row
/// still carries the whole selection.
class ModeChip extends StatelessWidget {
  const ModeChip({super.key, required this.label, required this.onRemove});

  final String label;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final accent = AppColors.accentOf(context);
    return Semantics(
      button: true,
      label: 'Remove $label',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          Haptics.lightTick();
          onRemove();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: accent),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: accent,
                ),
              ),
              const SizedBox(width: 5),
              Icon(LucideIcons.x, size: 11, color: accent),
            ],
          ),
        ),
      ),
    );
  }
}

/// A slider in the app's accent, for the controls that open one.
///
/// Wraps `CupertinoSlider` rather than the Material one: this app builds on
/// `WidgetsApp`, so there is no Material ancestor to inherit from.
class OptionSlider extends StatelessWidget {
  const OptionSlider({
    super.key,
    required this.value,
    required this.max,
    required this.onChanged,
    this.min = 0,
    this.divisions,
    this.semanticLabel,
    this.onChangeEnd,
  });

  final double value;
  final double min;
  final double max;
  final int? divisions;
  final ValueChanged<double> onChanged;
  final String? semanticLabel;

  /// Called once the rider lets go.
  final VoidCallback? onChangeEnd;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      slider: true,
      label: semanticLabel,
      value: value.round().toString(),
      child: CupertinoSlider(
        value: value.clamp(min, max),
        min: min,
        max: max,
        divisions: divisions,
        activeColor: AppColors.accentOf(context),
        onChanged: onChanged,
        onChangeEnd: onChangeEnd == null ? null : (_) => onChangeEnd!(),
      ),
    );
  }
}

/// The endpoints and midpoint printed under an [OptionSlider], so a position
/// on the track can be read without dragging it.
class SliderScaleLabels extends StatelessWidget {
  const SliderScaleLabels({super.key, required this.labels});

  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          for (final label in labels)
            Text(
              label,
              style: TextStyle(
                fontSize: 10.5,
                color: AppColors.black.withValues(alpha: 0.45),
              ),
            ),
        ],
      ),
    );
  }
}

/// The small-caps label over a group of options — a transport group's name, a
/// street leg's stage. Quiet enough to organise the ticks under it without
/// competing with them.
class OptionGroupHeading extends StatelessWidget {
  const OptionGroupHeading(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text.toUpperCase(),
    style: TextStyle(
      fontSize: 10.5,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.7,
      color: AppColors.black.withValues(alpha: 0.45),
    ),
  );
}
