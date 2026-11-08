
import 'dart:math';
import 'package:flutter/material.dart';

class CounterStyle {
  final Color background;
  final Color appBar;
  final Color accent;
  final Color text;
  final Color countColor;
  final Color inputBackground;
  final Color border;
  final Color reset;
  final Color buttonText;

  const CounterStyle({
    required this.background,
    required this.appBar,
    required this.accent,
    required this.text,
    required this.countColor,
    required this.inputBackground,
    required this.border,
    required this.reset,
    required this.buttonText,
  });

  Map<String, dynamic> toMap() {
    return {
      'background': background.toARGB32(),
      'appBar': appBar.toARGB32(),
      'accent': accent.toARGB32(),
      'text': text.toARGB32(),
      'countColor': countColor.toARGB32(),
      'inputBackground': inputBackground.toARGB32(),
      'border': border.toARGB32(),
      'reset': reset.toARGB32(),
      'buttonText': buttonText.toARGB32(),
    };
  }

  factory CounterStyle.fromMap(Map<String, dynamic> map) {
    return CounterStyle(
      background: Color(map['background']),
      appBar: Color(map['appBar']),
      accent: Color(map['accent']),
      text: Color(map['text']),
      countColor: Color(map['countColor']),
      inputBackground: Color(map['inputBackground']),
      border: Color(map['border']),
      reset: Color(map['reset']),
      buttonText: Color(map['buttonText']),
    );
  }

  static CounterStyle random() {
    final styles = [
      _create(0xFF101827, 0xFF17243A, 0xFF3978D7,
          0xFF75AEFF, 0xFF1D2A40),
      _create(0xFF1B1428, 0xFF281C3D, 0xFF9B6BDE,
          0xFFC5A0FF, 0xFF302342),
      _create(0xFF10231D, 0xFF19372C, 0xFF32A879,
          0xFF75D6A8, 0xFF1D3B30),
      _create(0xFF28151B, 0xFF3A1E28, 0xFFC64F68,
          0xFFFF91A5, 0xFF42232E),
      _create(0xFF211A13, 0xFF35291C, 0xFFD98A3A,
          0xFFFFBD70, 0xFF403021),
      _create(0xFF102326, 0xFF19373B, 0xFF24A6A6,
          0xFF75DEDE, 0xFF1D4145),
      _create(0xFF281725, 0xFF3C2237, 0xFFD45CA9,
          0xFFFF9BD9, 0xFF482A41),
      _create(0xFF111D2D, 0xFF1C2E47, 0xFF4285F4,
          0xFF8BB8FF, 0xFF243751),
      _create(0xFF272113, 0xFF3D321C, 0xFFD6A83F,
          0xFFFFD779, 0xFF493B22),
      _create(0xFF14232B, 0xFF203844, 0xFF57BBD5,
          0xFF9BE8F5, 0xFF294651),
    ];

    return styles[Random().nextInt(styles.length)];
  }

  static CounterStyle _create(
    int background,
    int appBar,
    int accent,
    int countColor,
    int inputBackground,
  ) {
    return CounterStyle(
      background: Color(background),
      appBar: Color(appBar),
      accent: Color(accent),
      text: Colors.white,
      countColor: Color(countColor),
      inputBackground: Color(inputBackground),
      border: Color(accent),
      reset: const Color(0xFFE05252),
      buttonText: Colors.white,
    );
  }
}
