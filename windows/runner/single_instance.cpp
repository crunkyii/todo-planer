#include "single_instance.h"

#ifdef _DEBUG
const wchar_t kAppWindowClass[] = L"TODO_PLANER_WINDOW_DEBUG";
constexpr const wchar_t kMutexName[] = L"Local\\ToDoPlaner.SingleInstance.Debug";
#else
const wchar_t kAppWindowClass[] = L"TODO_PLANER_WINDOW";
constexpr const wchar_t kMutexName[] = L"Local\\ToDoPlaner.SingleInstance";
#endif

namespace {

// Höchstens so viele Bytes werden weitergereicht (ein Link ist viel kürzer).
constexpr size_t kMaxPayload = 16 * 1024;

// Die Sperre gehört dem Prozess, bis er endet (Windows gibt sie dann frei).
HANDLE g_mutex = nullptr;

// Sucht das Fenster der ersten App. Sie kann gerade erst starten – dann kurz warten.
HWND FindAppWindow() {
  for (int i = 0; i < 50; ++i) {
    HWND hwnd = ::FindWindowW(kAppWindowClass, nullptr);
    if (hwnd) return hwnd;
    ::Sleep(100);
  }
  return nullptr;
}

}  // namespace

bool AcquireSingleInstance(const std::vector<std::string>& args) {
  g_mutex = ::CreateMutexW(nullptr, FALSE, kMutexName);
  if (g_mutex == nullptr || ::GetLastError() != ERROR_ALREADY_EXISTS) {
    // Erste App (oder die Sperre ging nicht – dann einfach normal starten).
    return true;
  }
  HWND hwnd = FindAppWindow();
  if (!hwnd) return false;

  // Die erste App darf ihr Fenster nach vorne holen: Dieser Start kam vom Vordergrund
  // (Flick, Explorer) und gibt das Recht weiter.
  DWORD pid = 0;
  ::GetWindowThreadProcessId(hwnd, &pid);
  if (pid) ::AllowSetForegroundWindow(pid);

  // Argumente als UTF-8, jedes mit \0 abgeschlossen.
  std::string payload;
  for (const auto& a : args) {
    if (payload.size() + a.size() + 1 > kMaxPayload) break;
    payload.append(a);
    payload.push_back('\0');
  }
  COPYDATASTRUCT data{};
  data.dwData = kForwardArgsId;
  data.cbData = static_cast<DWORD>(payload.size());
  data.lpData = payload.empty() ? nullptr : payload.data();
  DWORD_PTR result = 0;
  ::SendMessageTimeoutW(hwnd, WM_COPYDATA, 0, reinterpret_cast<LPARAM>(&data),
                        SMTO_ABORTIFHUNG, 3000, &result);
  // Falls die erste App die Nachricht nicht annimmt: wenigstens das Fenster zeigen.
  if (result == 0) BringToFront(hwnd);
  return false;
}

std::optional<std::vector<std::string>> ReadForwardedArgs(LPARAM lparam) {
  const auto* data = reinterpret_cast<const COPYDATASTRUCT*>(lparam);
  if (data == nullptr || data->dwData != kForwardArgsId ||
      data->cbData > kMaxPayload || (data->cbData > 0 && data->lpData == nullptr)) {
    return std::nullopt;
  }
  std::vector<std::string> args;
  const char* p = static_cast<const char*>(data->lpData);
  std::string current;
  for (DWORD i = 0; i < data->cbData; ++i) {
    if (p[i] == '\0') {
      args.push_back(current);
      current.clear();
    } else {
      current.push_back(p[i]);
    }
  }
  return args;
}

void BringToFront(HWND hwnd) {
  // Noch unsichtbar = die App startet gerade: Sie zeigt sich nach dem ersten Bild selbst
  // (Win32Window::Show) – vorher käme nur ein leeres Fenster.
  if (!::IsWindowVisible(hwnd)) return;
  if (::IsIconic(hwnd)) ::ShowWindow(hwnd, SW_RESTORE);
  ::SetForegroundWindow(hwnd);
}
