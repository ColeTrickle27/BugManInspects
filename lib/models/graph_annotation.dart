import 'dart:ui';

import 'graph_point.dart';

enum GraphAnnotationKind {
  marker,
  photo,
  text,
}

enum GraphMarkerType {
  termiteActivity('Termite Activity', 'AT', Color(0xFFE24A33)),
  termiteDamage('Termite Damage', 'TD', Color(0xFFD33A2C)),
  moisture('Moisture', 'M%', Color(0xFF168AAD)),
  standingWater('Standing Water', 'SW', Color(0xFF0077B6)),
  conduciveCondition('Conducive Condition', 'CC', Color(0xFFE0AD19)),
  treatmentArea('Treatment Area', 'TA', Color(0xFF245BDB)),
  baitStation('Bait Station', 'BS', Color(0xFF2E7D55)),
  crawlspaceIssue('Crawlspace Issue', 'CS', Color(0xFF7048D8)),
  plumbingLeak('Plumbing Leak', 'PL', Color(0xFF168AAD)),
  hvacCondensation('HVAC Condensation', 'HVAC', Color(0xFF5A9BD8)),
  insulationIssue('Insulation Issue', 'INS', Color(0xFFE5792A)),
  woodDecay('Wood Decay', 'WD', Color(0xFF8A5A2B)),
  accessPoint('Access Point', 'AP', Color(0xFF2E7D55)),
  entryPoint('Entry Point', 'EP', Color(0xFF111111)),
  rodentActivity('Rodent Activity', 'RA', Color(0xFF5B4B3A)),
  generalPestActivity('General Pest Activity', 'GP', Color(0xFF7A4E8A)),
  photoPoint('Photo Insert', 'PH', Color(0xFF2C6F9F)),
  notePoint('Note Point', 'N', Color(0xFF444444)),
  recommendationPoint('Recommendation', 'REC', Color(0xFF245BDB)),
  oldDamage('Old Damage', 'OD', Color(0xFF9A6B29)),
  damage('X - Damage', 'X', Color(0xFFD33A2C)),
  activeTermites('AT - Active Termites', 'AT', Color(0xFFE24A33)),
  oldTermiteActivity('OT - Old Termite Activity', 'OT', Color(0xFF9A6B29)),
  circle('Circle', 'C', Color(0xFF245BDB)),
  triangle('Triangle', 'T', Color(0xFF7048D8)),
  square('Square', 'S', Color(0xFF2E7D55)),
  camera('Camera', 'CAM', Color(0xFF2C6F9F)),
  woodFungi('W - Wood Destroying Fungi', 'W', Color(0xFF4D7F33)),
  oldHouseBorers('OHB - Old House Borers', 'OHB', Color(0xFF6E5332)),
  powderPostBeetles('PPB - Powder Post Beetles', 'PPB', Color(0xFF7A4E8A)),
  treatmentNote('Treatment Note', 'TXT', Color(0xFF222222));

  const GraphMarkerType(this.label, this.shortLabel, this.defaultColor);

  final String label;
  final String shortLabel;
  final Color defaultColor;
}

class GraphAnnotation {
  const GraphAnnotation({
    required this.kind,
    required this.point,
    required this.label,
    this.markerType = GraphMarkerType.damage,
    this.color,
    this.size = 1,
    this.rotationDegrees = 0,
    this.note = '',
    this.fontSize = 16,
    this.bold = false,
    this.italic = false,
    this.textColor = const Color(0xFF1C2B22),
    this.backgroundColor = const Color(0xFFFFF2B8),
    this.borderColor = const Color(0xFFC7A93C),
  });

  final GraphAnnotationKind kind;
  final GraphPoint point;
  final String label;
  final GraphMarkerType markerType;
  final Color? color;
  final double size;
  final double rotationDegrees;
  final String note;
  final double fontSize;
  final bool bold;
  final bool italic;
  final Color textColor;
  final Color backgroundColor;
  final Color borderColor;

  GraphAnnotation copyWith({
    GraphAnnotationKind? kind,
    GraphPoint? point,
    String? label,
    GraphMarkerType? markerType,
    Color? color,
    bool clearColor = false,
    double? size,
    double? rotationDegrees,
    String? note,
    double? fontSize,
    bool? bold,
    bool? italic,
    Color? textColor,
    Color? backgroundColor,
    Color? borderColor,
  }) {
    return GraphAnnotation(
      kind: kind ?? this.kind,
      point: point ?? this.point,
      label: label ?? this.label,
      markerType: markerType ?? this.markerType,
      color: clearColor ? null : color ?? this.color,
      size: size ?? this.size,
      rotationDegrees: rotationDegrees ?? this.rotationDegrees,
      note: note ?? this.note,
      fontSize: fontSize ?? this.fontSize,
      bold: bold ?? this.bold,
      italic: italic ?? this.italic,
      textColor: textColor ?? this.textColor,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      borderColor: borderColor ?? this.borderColor,
    );
  }
}
