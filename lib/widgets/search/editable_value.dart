import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../theme/app_colors.dart';

/// A value the search starts from — where, or when — written out as what it
/// currently is, and changed by tapping it.
///
/// Plain text rather than a button: the defaults are what most searches keep,
/// so they should read as a statement ("My Location, now"), with the chevron
/// and a pressed tint the only hint that either can be changed.
class EditableValue extends StatefulWidget {
  /// The origin: the line the eye lands on first.
  const EditableValue.primary({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.onTapDown,
    this.onTapCancel,
    this.emphasised = false,
    this.semanticsLabel,
  }) : _fontSize = 16,
       _muted = false;

  /// The time: under the origin, a step quieter.
  const EditableValue.secondary({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.onTapDown,
    this.onTapCancel,
    this.semanticsLabel,
  }) : emphasised = false,
       _fontSize = 14,
       _muted = true;

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final VoidCallback? onTapDown;
  final VoidCallback? onTapCancel;

  /// Accent text, for a value the app filled in rather than one the rider
  /// chose — My Location.
  final bool emphasised;

  final String? semanticsLabel;
  final double _fontSize;
  final bool _muted;

  @override
  State<EditableValue> createState() => _EditableValueState();
}

class _EditableValueState extends State<EditableValue> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final accent = AppColors.accentOf(context);
    final colour = widget.emphasised
        ? accent
        : AppColors.black.withValues(alpha: widget._muted ? 0.6 : 1);
    return Semantics(
      button: true,
      label: widget.semanticsLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        onTapDown: (_) {
          widget.onTapDown?.call();
          _setPressed(true);
        },
        onTapUp: (_) => _setPressed(false),
        onTapCancel: () {
          widget.onTapCancel?.call();
          _setPressed(false);
        },
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 90),
          opacity: _pressed ? 0.5 : 1,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(widget.icon, size: widget._fontSize, color: colour),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    widget.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colour,
                      fontSize: widget._fontSize,
                      fontWeight: widget._muted
                          ? FontWeight.w500
                          : FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 2),
                Icon(
                  LucideIcons.chevronDown,
                  size: widget._fontSize - 1,
                  color: AppColors.black.withValues(alpha: 0.4),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
