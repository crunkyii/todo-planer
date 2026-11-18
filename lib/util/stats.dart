import 'dart:math' as math;

// Rechnen für den Tab „Statistik“ – ohne Widgets, damit es sich einzeln testen lässt.

/// So viele Wochen zeigt die Heatmap („Aktivität“).
const int heatWeeks = 18;

/// Stufe 0–4 der Heatmap aus der Anzahl erledigter Aufgaben eines Tages.
int heatLevel(int n) => n == 0
    ? 0
    : n <= 1
    ? 1
    : n <= 3
    ? 2
    : n <= 5
    ? 3
    : 4;

/// Obere Achsen-Grenze des Balkendiagramms: mindestens 4, gerade Zahl.
int chartMax(Iterable<int> totals) => math.max(4, (totals.fold<int>(0, math.max) / 2).ceil() * 2);
