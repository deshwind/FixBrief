import 'package:flutter/animation.dart';

abstract final class MotionTokens {
  static const buttonFeedback = Duration(milliseconds: 130);
  static const smallChange = Duration(milliseconds: 220);
  static const cardTransition = Duration(milliseconds: 340);
  static const pageTransition = Duration(milliseconds: 420);
  static const backgroundLoop = Duration(seconds: 20);

  static const standardCurve = Curves.easeOutCubic;
  static const emphasizedCurve = Curves.easeInOutCubicEmphasized;
  static const springCurve = Curves.easeOutBack;
}
