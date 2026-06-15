import 'package:flutter/material.dart';
import '../models/seating_layout.dart';
import '../theme/app_theme.dart';

/// Zeichnet den Klassenraum als Rahmen und beschriftet die Seiten mit
/// Tafel 📋, Fenster 🪟 und Ausgang 🚪 – je nachdem, wo sie konfiguriert sind.
/// [child] (die Sitzplätze) wird innerhalb des Rahmens dargestellt.
class RoomFrame extends StatelessWidget {
  final SeatingLayout layout;
  final Widget child;
  final double inset;

  const RoomFrame({
    super.key,
    required this.layout,
    required this.child,
    this.inset = 44,
  });

  /// Welche Rollen liegen auf [side]?
  List<_Role> _rolesOn(RoomSide side) {
    final roles = <_Role>[];
    if (layout.boardSide == side) roles.add(_Role.board);
    if (layout.windowSide == side) roles.add(_Role.window);
    if (layout.exitSide == side) roles.add(_Role.exit);
    return roles;
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Raum-Wände
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.black12, width: 1.5),
            ),
          ),
        ),
        // Sitzplätze im Inneren
        Positioned.fill(
          child: Padding(
            padding: EdgeInsets.all(inset),
            child: child,
          ),
        ),
        // Seitenbeschriftungen
        _edge(RoomSide.top),
        _edge(RoomSide.bottom),
        _edge(RoomSide.left),
        _edge(RoomSide.right),
      ],
    );
  }

  Widget _edge(RoomSide side) {
    final roles = _rolesOn(side);
    if (roles.isEmpty) return const SizedBox.shrink();
    final vertical = side == RoomSide.left || side == RoomSide.right;

    // an Seitenrändern die Chips quer (vertikal) schreiben, damit sie nicht
    // in die Sitzreihen hineinragen
    Widget chipFor(_Role r) => vertical
        ? RotatedBox(
            quarterTurns: side == RoomSide.left ? 3 : 1,
            child: _RoleChip(role: r),
          )
        : _RoleChip(role: r);

    final chips = Flex(
      direction: vertical ? Axis.vertical : Axis.horizontal,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final r in roles) ...[
          chipFor(r),
          const SizedBox(width: 6, height: 6),
        ]
      ],
    );

    switch (side) {
      case RoomSide.top:
        return Positioned(
            top: 6, left: 0, right: 0, child: Center(child: chips));
      case RoomSide.bottom:
        return Positioned(
            bottom: 6, left: 0, right: 0, child: Center(child: chips));
      case RoomSide.left:
        return Positioned(
            left: 2, top: 0, bottom: 0, child: Center(child: chips));
      case RoomSide.right:
        return Positioned(
            right: 2, top: 0, bottom: 0, child: Center(child: chips));
    }
  }
}

enum _Role { board, window, exit }

extension _RoleInfo on _Role {
  String get text {
    switch (this) {
      case _Role.board:
        return '📋 Tafel';
      case _Role.window:
        return '🪟 Fenster';
      case _Role.exit:
        return '🚪 Ausgang';
    }
  }

  /// helle Fläche (passend zur Pastell-Palette)
  Color get fill {
    switch (this) {
      case _Role.board:
        return const Color(0xFFDCE8DC); // Grün
      case _Role.window:
        return const Color(0xFFD6E4F0); // Blau
      case _Role.exit:
        return const Color(0xFFF0E6D6); // Sand
    }
  }

  /// dunkle, lesbare Schriftfarbe derselben Familie
  Color get textColor {
    switch (this) {
      case _Role.board:
        return const Color(0xFF3A5240);
      case _Role.window:
        return const Color(0xFF2C4A66);
      case _Role.exit:
        return const Color(0xFF5E4B30);
    }
  }
}

class _RoleChip extends StatelessWidget {
  final _Role role;
  const _RoleChip({required this.role});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: role.fill,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: role.textColor.withValues(alpha: 0.18)),
      ),
      child: Text(role.text,
          style: TextStyle(
              fontSize: 13.5,
              color: role.textColor,
              fontWeight: FontWeight.w700)),
    );
  }
}
