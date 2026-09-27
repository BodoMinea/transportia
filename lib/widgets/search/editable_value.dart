import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../theme/app_colors.dart';

/// A value a search is built from — where from, when, where to — written out
/// as what it currently is and changed by tapping it.
///
/// Plain text rather than a button: the defaults are what most searches keep,
/// so the card should read as a statement ("My Location, leave now"), with
/// the accent chevron after each value the one sign that it can be changed.
class EditableValue extends StatefulWidget {
  /// Where the trip starts.
  const EditableValue.origin({
    super.key,
    required this.label,
    required this.onTap,
    this.semanticsLabel,
  }) : placeholder = null,
       onTapDown = null,
       onTapCancel = null,
       _fontSize = 17,
       _muted = false;

  /// When it leaves or arrives: under the origin, a step quieter.
  const EditableValue.time({
    super.key,
    required this.label,
    required this.onTap,
    this.onTapDown,
    this.onTapCancel,
    this.semanticsLabel,
  }) : placeholder = null,
       _fontSize = 15,
       _muted = true;

  /// Where it goes: the one value every search has to be given, so a size up,
  /// and asking for it with [placeholder] until it has been.
  const EditableValue.destination({
    super.key,
    required this.label,
    required String this.placeholder,
    required this.onTap,
    this.semanticsLabel,
  }) : onTapDown = null,
       onTapCancel = null,
       _fontSize = 18,
       _muted = false;

  final String label;

  /// Shown, with a search glyph in place of the chevron, while [label] is
  /// empty: there is nothing yet to change, only something to look for.
  final String? placeholder;

  final VoidCallback onTap;
  final VoidCallback? onTapDown;
  final VoidCallback? onTapCancel;
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
    final placeholder = widget.placeholder;
    final isEmpty = widget.label.isEmpty && placeholder != null;
    final colour = AppColors.black.withValues(
      alpha: isEmpty ? 0.45 : (widget._muted ? 0.6 : 1),
    );
    return Semantics(
      button: true,
      label: widget.semanticsLabel,
      // The whole row answers, not only the glyphs of the text: the value is
      // the target, however short it happens to be.
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
              children: [
                Flexible(
                  child: Text(
                    isEmpty ? placeholder : widget.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colour,
                      fontSize: widget._fontSize,
                      fontWeight: widget._muted || isEmpty
                          ? FontWeight.w500
                          : FontWeight.w600,
                    ),
                  ),
                ),
                SizedBox(width: isEmpty ? 8 : 4),
                // The chevron says "change this", in the accent like every
                // other control; the search glyph belongs to the placeholder
                // it follows, so it takes the placeholder's colour.
                Icon(
                  isEmpty ? LucideIcons.search : LucideIcons.chevronDown,
                  size: widget._fontSize,
                  color: isEmpty ? colour : accent,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
