import 'package:flutter/material.dart';

class AppAnimations {
  static const Duration normal = Duration(milliseconds: 300);

  static const Curve easeInOut = Curves.easeInOut;
  static const Curve easeOut = Curves.easeOut;

  static Widget fadeIn({
    required Widget child,
    Duration duration = normal,
    Curve curve = easeInOut,
  }) {
    return TweenAnimationBuilder<double>(
      duration: duration,
      curve: curve,
      tween: Tween(begin: 0.0, end: 1.0),
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: child,
        );
      },
      child: child,
    );
  }

  static Widget slideInFromBottom({
    required Widget child,
    Duration duration = normal,
    Curve curve = easeOut,
    double offset = 50.0,
  }) {
    return TweenAnimationBuilder<Offset>(
      duration: duration,
      curve: curve,
      tween: Tween(
        begin: Offset(0, offset),
        end: Offset.zero,
      ),
      builder: (context, value, child) {
        return Transform.translate(
          offset: value,
          child: child,
        );
      },
      child: child,
    );
  }

  static Widget scaleIn({
    required Widget child,
    Duration duration = normal,
    Curve curve = easeOut,
    double beginScale = 0.8,
  }) {
    return TweenAnimationBuilder<double>(
      duration: duration,
      curve: curve,
      tween: Tween(begin: beginScale, end: 1.0),
      builder: (context, value, child) {
        return Transform.scale(
          scale: value,
          child: child,
        );
      },
      child: child,
    );
  }
}
