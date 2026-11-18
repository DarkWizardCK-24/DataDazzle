import 'package:flutter/widgets.dart';

/// Layout breakpoints used across the app.
///
/// compact  < 600   (phones)
/// medium   600-1023 (tablets, small windows)
/// expanded >= 1024 (desktop, web, large tablets in landscape)
enum ScreenSize { compact, medium, expanded }

class Breakpoints {
  static const double medium = 600;
  static const double expanded = 1024;

  /// Max content width for list / dashboard style screens.
  static const double contentMaxWidth = 1200;

  /// Max content width for single-column forms.
  static const double formMaxWidth = 760;

  /// Max width for dialogs and bottom sheets.
  static const double dialogMaxWidth = 560;
  static const double sheetMaxWidth = 640;
}

ScreenSize screenSizeForWidth(double width) {
  if (width >= Breakpoints.expanded) return ScreenSize.expanded;
  if (width >= Breakpoints.medium) return ScreenSize.medium;
  return ScreenSize.compact;
}

extension ResponsiveContext on BuildContext {
  double get screenWidth => MediaQuery.sizeOf(this).width;
  ScreenSize get screenSize => screenSizeForWidth(screenWidth);
  bool get isCompact => screenSize == ScreenSize.compact;
  bool get isExpanded => screenSize == ScreenSize.expanded;
}

/// Number of grid columns for card layouts at a given available width.
int gridColumnsForWidth(
  double width, {
  double minTileWidth = 340,
  int max = 3,
}) {
  final n = (width / minTileWidth).floor();
  return n.clamp(1, max);
}

/// Centers [child] and caps its width at [maxWidth].
class MaxWidthBox extends StatelessWidget {
  final double maxWidth;
  final Widget child;
  final AlignmentGeometry alignment;

  const MaxWidthBox({
    super.key,
    required this.child,
    this.maxWidth = Breakpoints.contentMaxWidth,
    this.alignment = Alignment.topCenter,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}
