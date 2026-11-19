#ifndef RUNNER_SINGLE_INSTANCE_H_
#define RUNNER_SINGLE_INSTANCE_H_

#include <windows.h>

#include <optional>
#include <string>
#include <vector>

// Nur eine laufende App: Ein zweiter Start (z. B. über einen todoplaner://-Link aus dem
// Launcher Flick) reicht seine Argumente an das schon offene Fenster weiter und beendet sich.
//
// Debug-Builds (flutter run, Integrationstests) haben eigene Namen, damit sie nie an die
// installierte App weiterreichen – und umgekehrt.

// Fensterklasse des App-Fensters; daran findet ein zweiter Start das erste Fenster.
extern const wchar_t kAppWindowClass[];

// Kennung der WM_COPYDATA-Nachricht mit den weitergereichten Argumenten.
constexpr ULONG_PTR kForwardArgsId = 0x54504C31;  // „TPL1“

// Holt sich die Sperre „App läuft“. false = Es läuft schon eine App; dann wurden die
// Argumente an sie weitergereicht (oder es ging nicht) und dieser Start soll sich beenden.
bool AcquireSingleInstance(const std::vector<std::string>& args);

// Liest die Argumente aus einer WM_COPYDATA-Nachricht; nullopt = nicht von uns.
std::optional<std::vector<std::string>> ReadForwardedArgs(LPARAM lparam);

// Holt das Fenster nach vorne (auch aus der Taskleiste zurück).
void BringToFront(HWND hwnd);

#endif  // RUNNER_SINGLE_INSTANCE_H_
