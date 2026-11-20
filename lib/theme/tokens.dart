import 'package:material_ui/material_ui.dart';

import 'color_math.dart';

/// Ein App-Theme: die Hauptfarbe [primary], aus der alle anderen Farben berechnet werden.
class AppThemeDef {
  const AppThemeDef(this.id, this.primary);
  final String id;
  final Color primary;
}

/// Die 10 Themes aus dem Prototyp (`THEMES`).
const List<AppThemeDef> appThemes = [
  AppThemeDef('himmel', Color(0xFF3D9BE9)),
  AppThemeDef('ozean', Color(0xFF1E6FD9)),
  AppThemeDef('mint', Color(0xFF22A776)),
  AppThemeDef('wald', Color(0xFF3F8A4C)),
  AppThemeDef('sonne', Color(0xFFE9A21F)),
  AppThemeDef('abendrot', Color(0xFFE8664A)),
  AppThemeDef('beere', Color(0xFFC2457A)),
  AppThemeDef('lavendel', Color(0xFF7C68E8)),
  AppThemeDef('nord', Color(0xFF5E81AC)),
  AppThemeDef('graphit', Color(0xFF5B6470)),
];

AppThemeDef themeOf(String id) => appThemes.firstWhere((t) => t.id == id, orElse: () => appThemes.first);

/// Die 5 Farbvorgaben (`PRESETS`). Namen kommen aus den ARB-Dateien.
enum ColorPreset {
  skyBlue('#3D9BE9'),
  mintGreen('#34C38F'),
  sunYellow('#F5B83D'),
  coral('#F07A5F'),
  lavender('#8E7CF0');

  const ColorPreset(this.hex);
  final String hex;
}

/// Farbe der festen Aufgabe „Gewohnheiten“.
const String habitColorHex = '#F5B83D';

/// Alle Farben eines Themes – entspricht den CSS-Variablen `--p`, `--bg` … aus `applyTheme()`.
@immutable
class AppTokens extends ThemeExtension<AppTokens> {
  const AppTokens({
    required this.dark,
    required this.p,
    required this.onP,
    required this.pc,
    required this.onPc,
    required this.bg,
    required this.surf,
    required this.surf2,
    required this.line,
    required this.lineSoft,
    required this.text,
    required this.sub,
    required this.err,
    required this.errC,
    required this.onErrC,
    required this.inv,
    required this.onInv,
    required this.invP,
    required this.card,
    required this.glass,
    required this.glassStrong,
    required this.glassEdge,
    required this.glow,
    required this.glowStrong,
    required this.blob1,
    required this.cardShadow,
  });

  factory AppTokens.build(AppThemeDef th, {required bool dark}) {
    final h = th.primary;
    if (dark) {
      const b = darkBase;
      final pD = ensure(mix(h, white, 0.25), b, 6);
      return AppTokens(
        dark: true,
        p: pD,
        onP: ensure(mix(h, black, 0.75), pD, 7),
        pc: mix(h, b, 0.6),
        onPc: mix(h, white, 0.82),
        bg: b,
        surf: mix(b, h, 0.07),
        surf2: mix(b, h, 0.13),
        line: const Color(0xFF454A52),
        lineSoft: const Color(0xFF2A2E34),
        text: const Color(0xFFE3E5E9),
        sub: const Color(0xFFB8BDC6),
        err: const Color(0xFFFFB4AB),
        errC: const Color(0xFF93000A),
        onErrC: const Color(0xFFFFDAD6),
        inv: const Color(0xFFE3E5E9),
        onInv: const Color(0xFF2E3136),
        invP: ensure(h, const Color(0xFFE3E5E9), 4.5),
        card: mix(b, h, 0.09),
        glass: alpha(mix(b, h, 0.12), 0.7),
        glassStrong: alpha(mix(b, h, 0.1), 0.88),
        glassEdge: const Color(0x14FFFFFF),
        glow: alpha(h, 0.3),
        glowStrong: alpha(h, 0.35),
        blob1: alpha(h, 0.14),
        cardShadow: const [],
      );
    }
    // 4,8 statt 4,5: Die Primärfarbe steht auch als Text auf dem leicht getönten Hintergrund.
    final p = ensure(h, white, 4.8), pc = mix(h, white, 0.76);
    return AppTokens(
      dark: false,
      p: p,
      onP: white,
      pc: pc,
      onPc: ensure(mix(h, black, 0.6), pc, 7),
      bg: mix(h, white, 0.95),
      surf: white,
      surf2: mix(h, white, 0.87),
      line: mix(const Color(0xFFC9D0D9), h, 0.1),
      lineSoft: mix(const Color(0xFFE4E9EE), h, 0.08),
      text: const Color(0xFF1A1C20),
      sub: const Color(0xFF4A505A),
      err: const Color(0xFFBA1A1A),
      errC: const Color(0xFFFFDAD6),
      onErrC: const Color(0xFF410002),
      inv: const Color(0xFF2E3136),
      onInv: const Color(0xFFF1F3F6),
      invP: ensure(mix(h, white, 0.4), const Color(0xFF2E3136), 4.5),
      card: white,
      glass: const Color(0xA8FFFFFF),
      glassStrong: const Color(0xDBFFFFFF),
      glassEdge: const Color(0xE6FFFFFF),
      glow: alpha(h, 0.32),
      glowStrong: alpha(h, 0.22),
      blob1: alpha(h, 0.2),
      cardShadow: const [
        BoxShadow(color: Color(0x0D142846), offset: Offset(0, 1), blurRadius: 2),
        BoxShadow(color: Color(0x0F142846), offset: Offset(0, 4), blurRadius: 14),
      ],
    );
  }

  final bool dark;
  final Color p, onP, pc, onPc;
  final Color bg, surf, surf2, line, lineSoft;
  final Color text, sub;
  final Color err, errC, onErrC;
  final Color inv, onInv, invP;
  final Color card, glass, glassStrong, glassEdge;
  final Color glow, glowStrong, blob1;
  final List<BoxShadow> cardShadow;

  /// Abgeleitete Farben für eine Kategorie-/Gewohnheits-/Blockfarbe.
  ItemColors item(String hex) => ItemColors.of(parseHex(hex), dark: dark);

  /// Schatten unter schwebenden Elementen (Navigation, Menü, Snackbar).
  List<BoxShadow> get navShadow => const [BoxShadow(color: Color(0x29142846), offset: Offset(0, 8), blurRadius: 28)];
  List<BoxShadow> get popShadow => const [BoxShadow(color: Color(0x2E000000), offset: Offset(0, 10), blurRadius: 30)];
  List<BoxShadow> get sheetShadow => const [BoxShadow(color: Color(0x24000000), offset: Offset(0, -6), blurRadius: 24)];

  /// Kleiner Schatten der Mini-Karten in der Theme-Vorschau.
  List<BoxShadow> get previewShadow => const [BoxShadow(color: Color(0x14000000), offset: Offset(0, 1), blurRadius: 3)];
  List<BoxShadow> get previewFabShadow => const [
    BoxShadow(color: Color(0x2E000000), offset: Offset(0, 2), blurRadius: 6),
  ];
  List<BoxShadow> get snackShadow => const [BoxShadow(color: Color(0x40000000), offset: Offset(0, 4), blurRadius: 12)];
  List<BoxShadow> get fabShadow => [
    BoxShadow(color: glow, offset: const Offset(0, 6), blurRadius: 18),
    const BoxShadow(color: Color(0x2E000000), offset: Offset(0, 2), blurRadius: 6),
  ];
  Color get scrim => const Color(0x610A141E);

  @override
  AppTokens copyWith() => this;

  @override
  AppTokens lerp(ThemeExtension<AppTokens>? other, double t) => other is AppTokens && t >= 0.5 ? other : this;
}

/// Radien und Abstände (aus dem CSS des Prototyps).
abstract final class Sizes {
  static const double rCard = 12;
  static const double rCardLarge = 22;
  static const double rTile = 20;
  static const double rSheet = 28;
  static const double rNav = 32;
  static const double rNavInd = 28;
  static const double rMenu = 16;
  static const double rInput = 10;
  static const double rSlim = 14;
  static const double rDtBtn = 16;
  static const double rPop = 18;
  static const double rSnack = 8;
  static const double rToast = 20;
  static const double rSeg = 20;
  static const double rCalDay = 12;
  static const double rChoice = 22;
  static const double rBlock = 6;
  static const double rHabitDay = 15;
  static const double rHeat = 3;

  static const double iconBtn = 44;

  /// Symbol bzw. Schritt-Nummer in der Flick-Anleitung.
  static const double flickIcon = 32;
  static const double chipH = 36;
  static const double navH = 64;
  static const double navGap = 12;
  static const double fab = 60;
  static const double fabRight = 18;
  static const double fabBottom = 90;
  static const double contentBottom = 164;
  static const double weekBottom = 84;
  static const double hour = 56;
  static const double wheelItem = 40;
  static const double wheelH = 200;
  static const double maxWidth = 560;

  /// Ab dieser Fensterbreite (PC, Tablet quer) steht die Navigation links statt unten.
  static const double wideWidth = 900;

  /// Breites Layout nur, wenn das Fenster auch hoch genug ist – ein Handy im Querformat
  /// (z. B. 915×412) bleibt beim Handy-Layout.
  static const double wideMinHeight = 600;
  static bool isWide(Size window) => window.width >= wideWidth && window.height >= wideMinHeight;

  /// Der Kalender zeigt den Tag erst neben dem Monat, wenn dem Monat genug Platz bleibt.
  static const double calTwoPane = 780;
  static const double sideNavW = 236;

  /// Unterer Rand der Listen im breiten Layout (dort liegt keine Leiste über dem Inhalt).
  static const double wideBottom = 28;

  /// Breite des Inhalts im breiten Layout: Listen bleiben lesbar schmal, Raster dürfen breiter werden.
  static const double wideList = 860;

  /// Aufgaben am PC: ab dieser Inhaltsbreite stehen die Listen nebeneinander, daneben die
  /// Seitenleiste ([boardSide]). Schmaler als [boardListMin] wird eine Liste nie – erst
  /// darunter zeigt das Fenster weniger Listen als eingestellt.
  static const double wideBoard = 1600;
  static const double boardMin = 940;
  static const double boardSide = 340;
  static const double boardListMin = 190;

  /// Farbpunkt neben einem großen Titel (Ansicht eines Blocks).
  static const double dotLarge = 14;

  /// Am Handy: so hoch ist ein gezogener Abschnitt am Finger höchstens.
  static const double dragPreviewMax = 320;

  /// Seitenleiste: So viel Höhe brauchen „Heute“, der Kopf der Gewohnheiten und der Monat.
  /// Was vom Fenster übrig bleibt, bekommt die Liste der Gewohnheiten – mindestens
  /// [sideHabitsMin]; sind es mehr, scrollt man in der Liste, der Monat bleibt stehen.
  static const double sideFixed = 600;
  static const double sideHabitsMin = 132;
  static const double wideGrid = 1240;
  static const double wideWeek = 1600;
  static const double calSide = 400;

  /// Bis zu dieser Fensterhöhe rücken Kopf und Abstände zusammen (Querformat am Handy).
  static const double lowHeight = 640;

  /// Bis zu dieser Breite gilt ein Handy als schmal: kleinere Schrift im Wochenplan, kürzere Chips.
  static const double narrowWidth = 360;

  /// Blättern per Wischen: so weit gezogen, gleitet der Monat bzw. die Woche hinaus;
  /// kürzer federt er zurück.
  static const double swipeThreshold = 90;

  /// Breite des Streifens, in dem beim Ziehen der Name des nächsten Monats steht.
  static const double swipePeek = 120;

  /// So weit gleitet der Titel (Monat, Kalenderwoche) beim Blättern hinaus.
  static const double titleShift = 30;

  /// Funken, wenn alle Gewohnheiten des Tages erledigt sind: Anzahl, Größe und Flugweite.
  static const int sparkCount = 14;
  static const double spark = 8;
  static const double sparkDistance = 80;
}

/// Schriftgrößen (px aus dem CSS).
abstract final class Fs {
  static const double base = 14;

  /// Fließtext auf ganzen Seiten (Einleitung, leere Liste).
  static const double body = 15;
  static const double title = 22;
  static const double sheetTitle = 20;
  static const double task = 15.5;
  static const double meta = 12.5;
  static const double section = 12.5;
  static const double nav = 10.5;
  static const double small = 12;
  static const double tiny = 10.5;
  static const double micro = 9.5;
  static const double input = 16;
  static const double slim = 17;
  static const double wheel = 22;
  static const double tile = 26;
  static const double login = 28;

  /// Ziffern gleich breit – Zahlen und Uhrzeiten springen nicht, wenn sich ihr Wert ändert.
  static const tabular = [FontFeature.tabularFigures()];
}

/// Bewegung: Feder-Kurven und Dauern aus dem CSS.
abstract final class Motion {
  static const Curve spring = Cubic(0.34, 1.56, 0.64, 1);
  static const Curve springSoft = Cubic(0.34, 1.5, 0.5, 1);
  static const Curve springNav = Cubic(0.34, 1.45, 0.5, 1);
  static const Curve sheetUp = Cubic(0.3, 1.25, 0.5, 1);
  static const Curve snackUp = Cubic(0.3, 1.3, 0.5, 1);
  static const Curve toastIn = Cubic(0.34, 1.7, 0.5, 1);
  static const Curve enter = Cubic(0.22, 1.15, 0.36, 1);
  static const Curve zoom = Cubic(0.22, 1.2, 0.36, 1);
  static const Curve grow = Cubic(0.34, 1.35, 0.5, 1);
  static const Curve growX = Cubic(0.34, 1.3, 0.5, 1);
  static const Curve check = Cubic(0.34, 1.9, 0.5, 1);
  static const Curve release = Cubic(0.25, 0.8, 0.35, 1);

  static const Duration press = Duration(milliseconds: 120);
  static const Duration springBack = Duration(milliseconds: 550);
  static const Duration releaseDur = Duration(milliseconds: 600);
  static const Duration glow = Duration(milliseconds: 750);
  static const Duration nav = Duration(milliseconds: 600);
  static const Duration page = Duration(milliseconds: 500);
  static const Duration sheet = Duration(milliseconds: 550);
  static const Duration menu = Duration(milliseconds: 420);
  static const Duration pop = Duration(milliseconds: 400);
  static const Duration fast = Duration(milliseconds: 200);
  static const Duration bar = Duration(milliseconds: 800);
  static const Duration fill = Duration(milliseconds: 900);

  /// Hervorheben einer Aufgabe (zweimal größer werden und leuchten).
  static const Duration focus = Duration(milliseconds: 1600);

  // Blättern im Kalender und im Wochenplan: Der Inhalt gleitet hinaus ([pageOut]), ab
  // [pageInAt] kommt der neue von der anderen Seite herein ([pageIn]). Der Titel läuft mit.
  static const Curve pageOutCurve = Cubic(0.4, 0, 1, 1);
  static const Curve emphasized = Cubic(0.2, 0, 0, 1);
  static const Curve swipeBack = Cubic(0.34, 1.5, 0.64, 1);
  static const Duration pageOut = Duration(milliseconds: 180);
  static const Duration pageInAt = Duration(milliseconds: 220);
  static const Duration pageIn = Duration(milliseconds: 320);
  static const Duration pageInFade = Duration(milliseconds: 220);
  static const Duration titleOut = Duration(milliseconds: 150);
  static const Duration titleIn = Duration(milliseconds: 260);
  static const Duration swipeBackDur = Duration(milliseconds: 360);

  /// Deckkraft des Inhalts, während er hinaus- bzw. hereingleitet.
  static const double pageDim = 0.4;

  /// Bei „Animationen reduzieren“: statt Gleiten nur ein kurzes Überblenden.
  static const Duration crossFade = Duration(milliseconds: 150);

  // Abhaken: Kreis springt (0,6 → 1,2 → 1), Haken zeichnet sich, Splash spritzt und vergeht.
  static const Duration checkGrowAt = Duration(milliseconds: 30);
  static const Duration checkGrow = Duration(milliseconds: 200);
  static const Duration checkSettleAt = Duration(milliseconds: 300);
  static const Duration checkSettle = Duration(milliseconds: 220);
  static const Duration checkDraw = Duration(milliseconds: 260);
  static const Duration checkTotal = Duration(milliseconds: 1100);
  static const double checkFrom = 0.6;
  static const double checkPeak = 1.2;

  /// Tropfen fliegen hinaus ([splashFly], Spritzer [splashDotFly]) und ziehen sich ab
  /// [checkSettleAt] zusammen ([splashFade]).
  static const Curve splashOut = Cubic(0.2, 0.8, 0.3, 1);
  static const Duration splashFly = Duration(milliseconds: 240);
  static const Duration splashDotFly = Duration(milliseconds: 280);
  static const Duration splashDotFade = Duration(milliseconds: 120);
  static const Duration splashFade = Duration(milliseconds: 360);
  static const Duration splashTotal = Duration(milliseconds: 660);

  /// Titel wird durchgestrichen und blasser.
  static const Duration strikeDelay = Duration(milliseconds: 150);
  static const Duration strike = Duration(milliseconds: 320);
  static const Duration doneFadeDelay = Duration(milliseconds: 300);
  static const Duration doneFade = Duration(milliseconds: 400);

  /// Serie zählt hoch: die neue Zahl kommt von unten.
  static const Duration countDelay = Duration(milliseconds: 200);
  static const Duration count = Duration(milliseconds: 300);
  static const double countShift = 10;

  /// Funken, wenn alle Gewohnheiten erledigt sind; jeder dritte startet [sparkStagger] später.
  static const Duration sparks = Duration(milliseconds: 750);
  static const Duration sparkStagger = Duration(milliseconds: 40);

  /// „Animationen reduzieren“ des Systems.
  static bool reduced(BuildContext context) => MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  static Duration of(BuildContext context, Duration d) => reduced(context) ? Duration.zero : d;
}

extension TokensX on BuildContext {
  AppTokens get tok => Theme.of(this).extension<AppTokens>()!;
}
