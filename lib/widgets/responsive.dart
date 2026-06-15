import 'package:flutter/widgets.dart';

/// Zentriert Inhalte auf breiten Bildschirmen (Tablets, iPad, Querformat)
/// und begrenzt sie auf eine angenehme Lesebreite, statt sie über die
/// gesamte Breite zu strecken.
class ResponsiveCenter extends StatelessWidget {
  final Widget child;
  final double maxWidth;

  const ResponsiveCenter({
    super.key,
    required this.child,
    this.maxWidth = 720,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}

/// True auf breiten Layouts (Tablet/Querformat).
bool isWideScreen(BuildContext context) =>
    MediaQuery.sizeOf(context).width >= 600;
