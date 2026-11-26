//
// ********************************************************************
// * Strata: a Geant4 application for ion irradiation of layered       *
// * targets.                                                          *
// ********************************************************************
//
// \file Strata/api/strata_pipe.cc
// \brief Processes and pipes, once per platform

#include "strata_pipe.hh"

#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <string>

#ifdef _WIN32
#define WIN32_LEAN_AND_MEAN
#define NOMINMAX
#include <windows.h>

#include <algorithm>
#include <cwchar>
#include <vector>
#else
#include <dlfcn.h>
#include <spawn.h>
#include <sys/wait.h>
#include <unistd.h>

#include <cerrno>
#include <csignal>

extern "C" char** environ;
#endif

namespace strata {

#ifdef _WIN32

//==============================================================================
// Windows
//==============================================================================

const Pipe kNoPipe = nullptr;
const Process kNoProcess = nullptr;
const char* const kEngineName = "strata_engine.exe";

namespace {

// Paths are UTF-8 on the way through, so a directory with an accent in it
// survives; the wide forms are used at the Win32 boundary only
std::wstring Wide(const std::string& text) {
    if (text.empty()) return std::wstring();
    const int n = ::MultiByteToWideChar(CP_UTF8, 0, text.data(), static_cast<int>(text.size()), nullptr, 0);
    if (n <= 0) return std::wstring();
    std::wstring out(static_cast<std::size_t>(n), L'\0');
    ::MultiByteToWideChar(CP_UTF8, 0, text.data(), static_cast<int>(text.size()), &out[0], n);
    return out;
}

std::string Utf8(const std::wstring& text) {
    if (text.empty()) return std::string();
    const int n = ::WideCharToMultiByte(CP_UTF8, 0, text.data(), static_cast<int>(text.size()), nullptr, 0, nullptr, nullptr);
    if (n <= 0) return std::string();
    std::string out(static_cast<std::size_t>(n), '\0');
    ::WideCharToMultiByte(CP_UTF8, 0, text.data(), static_cast<int>(text.size()), &out[0], n, nullptr, nullptr);
    return out;
}

std::wstring GetVar(const wchar_t* name) {
    const DWORD n = ::GetEnvironmentVariableW(name, nullptr, 0);
    if (n == 0) return std::wstring();
    std::wstring buffer(n, L'\0');
    const DWORD got = ::GetEnvironmentVariableW(name, &buffer[0], n);
    if (got == 0 || got >= n) return std::wstring();
    buffer.resize(got);
    return buffer;
}

bool IsDirectory(const std::wstring& path) {
    if (path.empty()) return false;
    const DWORD attributes = ::GetFileAttributesW(path.c_str());
    return attributes != INVALID_FILE_ATTRIBUTES
           && (attributes & FILE_ATTRIBUTE_DIRECTORY) != 0;
}

std::wstring DirectoryOf(const std::wstring& path) {
    const std::size_t cut = path.find_last_of(L"\\/");
    return cut == std::wstring::npos ? std::wstring() : path.substr(0, cut);
}

// Windows has no run path.  On macOS and Linux the engine finds Geant4
// through the one CMake bakes in; here it is the PATH the engine starts with
// that has to name Geant4's bin directory, and a front end launched from
// the Start menu or Explorer has whatever PATH the system has, which need
// not mention Geant4 at all.  The engine then dies in the loader with
// STATUS_DLL_NOT_FOUND before it reads its first request.  So the engine is
// given, ahead of the PATH it would inherit:
//   - its own directory (an installer may put the Geant4 DLLs beside it),
//   - %STRATA_GEANT4_DIR%\bin, which the front end sets from its
//     preferences,
//   - the bin directory of the Geant4 this was built against, when it
//     still exists.
std::wstring EnginePathVariable(const std::wstring& enginePath) {
    std::vector<std::wstring> dirs;
    dirs.push_back(DirectoryOf(enginePath));

    const std::wstring g4 = GetVar(L"STRATA_GEANT4_DIR");
    if (!g4.empty()) {
        dirs.push_back(g4 + L"\\bin");
        dirs.push_back(g4);              // in case it already names bin
    }
#ifdef STRATA_GEANT4_BINDIR
    dirs.push_back(Wide(STRATA_GEANT4_BINDIR));
#endif

    std::wstring path;
    for (const std::wstring& d : dirs) {
        if (!IsDirectory(d)) continue;
        path += d;
        path += L';';
    }
    path += GetVar(L"PATH");
    return path;
}

// The variable's name in one "NAME=value" entry.  Entries such as "=C:=C:\"
// start with '=', which is part of their name
std::wstring NameOf(const std::wstring& entry) {
    const std::size_t eq = entry.find(L'=', 1);
    return eq == std::wstring::npos ? entry : entry.substr(0, eq);
}

bool SameName(const std::wstring& a, const std::wstring& b) {
    return ::CompareStringOrdinal(a.c_str(), static_cast<int>(a.size()),
                                  b.c_str(), static_cast<int>(b.size()), TRUE) == CSTR_EQUAL;
}

// This process's environment with the named variables replaced, as the
// sorted, double-NUL-terminated block CreateProcessW takes.  The engine is
// given its own copy rather than this process's being edited, so nothing
// else this process starts later sees the engine's variables
std::vector<wchar_t> EnvironmentBlock(const std::vector<std::pair<std::wstring, std::wstring>>& set) {
    std::vector<std::wstring> entries;

    wchar_t* block = ::GetEnvironmentStringsW();
    if (block != nullptr) {
        for (const wchar_t* at = block; *at != L'\0'; at += std::wcslen(at) + 1) {
            const std::wstring entry(at);
            const std::wstring name = NameOf(entry);
            bool replaced = false;
            for (const auto& kv : set) replaced = replaced || SameName(name, kv.first);
            if (!replaced) entries.push_back(entry);
        }
        ::FreeEnvironmentStringsW(block);
    }
    for (const auto& kv : set) entries.push_back(kv.first + L"=" + kv.second);

    std::sort(entries.begin(), entries.end(), [](const std::wstring& a, const std::wstring& b) {
        const std::wstring na = NameOf(a), nb = NameOf(b);
        return ::CompareStringOrdinal(na.c_str(), static_cast<int>(na.size()),
                                      nb.c_str(), static_cast<int>(nb.size()), TRUE) == CSTR_LESS_THAN;
    });

    std::vector<wchar_t> out;
    for (const std::wstring& e : entries) {
        out.insert(out.end(), e.begin(), e.end());
        out.push_back(L'\0');
    }
    out.push_back(L'\0');
    return out;
}

}  // namespace

bool PipePair(PipeEnds& ends, bool parentWrites) {
    SECURITY_ATTRIBUTES sa;
    sa.nLength = sizeof(sa);
    sa.lpSecurityDescriptor = nullptr;
    sa.bInheritHandle = TRUE;

    HANDLE readEnd = nullptr;
    HANDLE writeEnd = nullptr;
    if (!::CreatePipe(&readEnd, &writeEnd, &sa, 0)) return false;

    ends.parent = parentWrites ? writeEnd : readEnd;
    ends.child = parentWrites ? readEnd : writeEnd;

    // The engine must not inherit the end we keep, or closing ours never
    // reaches it as an end of file
    if (!::SetHandleInformation(ends.parent, HANDLE_FLAG_INHERIT, 0)) {
        ::CloseHandle(readEnd);
        ::CloseHandle(writeEnd);
        ends.parent = kNoPipe;
        ends.child = kNoPipe;
        return false;
    }
    return true;
}

void PipeClose(Pipe& p) {
    if (p != kNoPipe) ::CloseHandle(p);
    p = kNoPipe;
}

bool PipeWriteAll(Pipe p, const void* data, std::size_t n) {
    const auto* at = static_cast<const unsigned char*>(data);
    while (n > 0) {
        DWORD wrote = 0;
        if (!::WriteFile(p, at, static_cast<DWORD>(n), &wrote, nullptr)) return false;
        if (wrote == 0) return false;
        at += wrote;
        n -= wrote;
    }
    return true;
}

bool PipeReadAll(Pipe p, void* data, std::size_t n) {
    auto* at = static_cast<unsigned char*>(data);
    while (n > 0) {
        DWORD got = 0;
        if (!::ReadFile(p, at, static_cast<DWORD>(n), &got, nullptr)) {
            return false;        // ERROR_BROKEN_PIPE: the other end closed
        }
        if (got == 0) return false;
        at += got;
        n -= got;
    }
    return true;
}

std::string PipeToText(Pipe p) {
    return std::to_string(static_cast<unsigned long long>(reinterpret_cast<std::uintptr_t>(p)));
}

Pipe PipeFromText(const char* text) {
    if (text == nullptr || *text == '\0') return kNoPipe;
    const unsigned long long value = std::strtoull(text, nullptr, 10);
    if (value == 0ULL) return kNoPipe;
    return reinterpret_cast<Pipe>(static_cast<std::uintptr_t>(value));
}

bool ProcessStart(const std::string& path, const PipeEnds& toChild, const PipeEnds& fromChild, Process& out) {
    const std::wstring wpath = Wide(path);

    std::vector<wchar_t> environment = EnvironmentBlock({
        {L"STRATA_FD_IN", Wide(PipeToText(toChild.child))},
        {L"STRATA_FD_OUT", Wide(PipeToText(fromChild.child))},
        {L"PATH", EnginePathVariable(wpath)},
    });

    // Only the engine's two ends are inherited.  bInheritHandles alone hands
    // over every inheritable handle in this process, and a front end that
    // runs other programs through pipes of its own (a TProcess reading a
    // download, say) would then never see those pipes close while the
    // engine lives
    SIZE_T attributeSize = 0;
    ::InitializeProcThreadAttributeList(nullptr, 1, 0, &attributeSize);
    std::vector<unsigned char> attributeBuffer(attributeSize);
    auto* attributes = reinterpret_cast<LPPROC_THREAD_ATTRIBUTE_LIST>(attributeBuffer.data());
    if (!::InitializeProcThreadAttributeList(attributes, 1, 0, &attributeSize)) return false;

    HANDLE inherited[2] = {toChild.child, fromChild.child};
    if (!::UpdateProcThreadAttribute(attributes, 0, PROC_THREAD_ATTRIBUTE_HANDLE_LIST,
                                     inherited, sizeof(inherited), nullptr, nullptr)) {
        ::DeleteProcThreadAttributeList(attributes);
        return false;
    }

    STARTUPINFOEXW si;
    ::ZeroMemory(&si, sizeof(si));
    si.StartupInfo.cb = sizeof(si);
    si.lpAttributeList = attributes;

    PROCESS_INFORMATION pi;
    ::ZeroMemory(&pi, sizeof(pi));

    // CreateProcess writes to the command line it is handed, so it cannot be
    // a literal or the data of a temporary
    std::wstring command = L"\"" + wpath + L"\"";
    command.push_back(L'\0');

    // The engine is a console program started by a window: without
    // CREATE_NO_WINDOW it gets a console of its own and the user sees it flash
    const DWORD flags = CREATE_NO_WINDOW | CREATE_UNICODE_ENVIRONMENT | EXTENDED_STARTUPINFO_PRESENT;

    // A child takes its error mode from this process.  Without
    // SEM_FAILCRITICALERRORS a missing Geant4 DLL puts up the loader's
    // "was not found" box on the user's desktop, once per attempt to start
    // the engine, although the engine itself has no window; with it the
    // engine simply exits with STATUS_DLL_NOT_FOUND, which the client turns
    // into an error message.  The same goes for the crash dialog
    const UINT errorMode = ::GetErrorMode();
    ::SetErrorMode(errorMode | SEM_FAILCRITICALERRORS | SEM_NOGPFAULTERRORBOX);
    const BOOL started = ::CreateProcessW(wpath.c_str(), &command[0], nullptr, nullptr,
                                          TRUE, flags, environment.data(), nullptr,
                                          &si.StartupInfo, &pi);
    ::SetErrorMode(errorMode);
    ::DeleteProcThreadAttributeList(attributes);
    if (!started) return false;

    ::CloseHandle(pi.hThread);
    out = pi.hProcess;
    return true;
}

void ProcessStop(Process& p, int graceMs) {
    if (p == kNoProcess) return;
    if (::WaitForSingleObject(p, static_cast<DWORD>(graceMs)) != WAIT_OBJECT_0) {
        ::TerminateProcess(p, 1);
        ::WaitForSingleObject(p, 5000);
    }
    ::CloseHandle(p);
    p = kNoProcess;
}

bool ProcessExitCode(Process p, int waitMs, unsigned long& code) {
    if (p == kNoProcess) return false;
    if (::WaitForSingleObject(p, static_cast<DWORD>(waitMs)) != WAIT_OBJECT_0) return false;
    DWORD c = 0;
    if (!::GetExitCodeProcess(p, &c) || c == STILL_ACTIVE) return false;
    code = c;
    return true;
}

std::string ProcessExitText(unsigned long code) {
    char hex[32];
    std::snprintf(hex, sizeof(hex), "0x%08lX", code);
    switch (code) {
    case 0xC0000135UL:   // STATUS_DLL_NOT_FOUND
        return std::string(kEngineName) + " could not find a DLL it needs (" + hex + "). "
               "Geant4's bin directory is not on its PATH: set the Geant4 directory in "
               "the preferences, set STRATA_GEANT4_DIR, or add <Geant4>\\bin to PATH";
    case 0xC0000139UL:   // STATUS_ENTRYPOINT_NOT_FOUND
        return std::string(kEngineName) + " loaded a DLL that lacks a function it needs (" + hex + "). "
               "Another Geant4 (or Qt, or Visual C++ runtime) found earlier on PATH does not "
               "match the one it was built against";
    case 0xC000007BUL:   // STATUS_INVALID_IMAGE_FORMAT
        return std::string(kEngineName) + " found a DLL built for another architecture (" + hex + "), "
               "a 32-bit DLL earlier on PATH than the 64-bit one";
    case 0xC0000005UL:
        return std::string(kEngineName) + " crashed with an access violation (" + hex + ")";
    case 0xC0000409UL:
        return std::string(kEngineName) + " aborted (" + hex + "), usually an uncaught exception "
               "or a Geant4 fatal error";
    default:
        return std::string(kEngineName) + " exited with code " + std::to_string(code) + " (" + hex + ")";
    }
}

std::string ThisLibraryDir() {
    HMODULE self = nullptr;
    if (!::GetModuleHandleExW(GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS | GET_MODULE_HANDLE_EX_FLAG_UNCHANGED_REFCOUNT,
                              reinterpret_cast<LPCWSTR>(&ThisLibraryDir), &self)) {
        return std::string();
    }

    std::wstring buffer(MAX_PATH, L'\0');
    DWORD n = ::GetModuleFileNameW(self, &buffer[0], static_cast<DWORD>(buffer.size()));
    while (n >= buffer.size()) {         // the path did not fit
        buffer.resize(buffer.size() * 2, L'\0');
        n = ::GetModuleFileNameW(self, &buffer[0], static_cast<DWORD>(buffer.size()));
    }
    if (n == 0) return std::string();
    buffer.resize(n);

    const std::size_t cut = buffer.find_last_of(L"\\/");
    if (cut == std::wstring::npos) return std::string();
    return Utf8(buffer.substr(0, cut));
}

bool Runnable(const std::string& path) {
    if (path.empty()) return false;
    const DWORD attributes = ::GetFileAttributesW(Wide(path).c_str());
    return attributes != INVALID_FILE_ATTRIBUTES
           && (attributes & FILE_ATTRIBUTE_DIRECTORY) == 0;
}

std::string EngineOverride() {
    const DWORD n = ::GetEnvironmentVariableW(L"STRATA_ENGINE", nullptr, 0);
    if (n == 0) return std::string();
    std::wstring buffer(n, L'\0');
    const DWORD got = ::GetEnvironmentVariableW(L"STRATA_ENGINE", &buffer[0], n);
    if (got == 0 || got >= n) return std::string();
    buffer.resize(got);
    return Utf8(buffer);
}

#else

//==============================================================================
// POSIX
//==============================================================================

const Pipe kNoPipe = -1;
const Process kNoProcess = -1;
const char* const kEngineName = "strata_engine";

bool PipePair(PipeEnds& ends, bool parentWrites) {
    int fd[2] = {-1, -1};
    if (::pipe(fd) != 0) return false;
    ends.parent = parentWrites ? fd[1] : fd[0];
    ends.child = parentWrites ? fd[0] : fd[1];
    return true;
}

void PipeClose(Pipe& p) {
    if (p >= 0) ::close(p);
    p = kNoPipe;
}

bool PipeWriteAll(Pipe p, const void* data, std::size_t n) {
    const auto* at = static_cast<const unsigned char*>(data);
    while (n > 0) {
        const ssize_t k = ::write(p, at, n);
        if (k <= 0) {
            if (k < 0 && errno == EINTR) continue;
            return false;
        }
        at += k;
        n -= static_cast<std::size_t>(k);
    }
    return true;
}

bool PipeReadAll(Pipe p, void* data, std::size_t n) {
    auto* at = static_cast<unsigned char*>(data);
    while (n > 0) {
        const ssize_t k = ::read(p, at, n);
        if (k <= 0) {
            if (k < 0 && errno == EINTR) continue;
            return false;        // the other end closed, or died
        }
        at += k;
        n -= static_cast<std::size_t>(k);
    }
    return true;
}

std::string PipeToText(Pipe p) {
    return std::to_string(p);
}

Pipe PipeFromText(const char* text) {
    if (text == nullptr || *text == '\0') return kNoPipe;
    const int fd = std::atoi(text);
    return fd > 2 ? fd : kNoPipe;
}

bool ProcessStart(const std::string& path, const PipeEnds& toChild, const PipeEnds& fromChild, Process& out) {
    // The ends are handed over by number rather than moved onto fixed ones:
    // moving them collides, because the number an end is to be moved to is
    // often another end of the same pair, and the actions apply in order
    posix_spawn_file_actions_t actions;
    posix_spawn_file_actions_init(&actions);
    // Geant4 writes to stdout; send it to stderr so that a front end parsing
    // its own stdout is not handed the engine's commentary
    posix_spawn_file_actions_adddup2(&actions, 2, 1);
    posix_spawn_file_actions_addclose(&actions, toChild.parent);
    posix_spawn_file_actions_addclose(&actions, fromChild.parent);

    ::setenv("STRATA_FD_IN", PipeToText(toChild.child).c_str(), 1);
    ::setenv("STRATA_FD_OUT", PipeToText(fromChild.child).c_str(), 1);

    char* argv[] = {const_cast<char*>(path.c_str()), nullptr};

    pid_t pid = -1;
    const int rc = ::posix_spawn(&pid, path.c_str(), &actions, nullptr, argv, environ);
    posix_spawn_file_actions_destroy(&actions);
    if (rc != 0) return false;

    out = pid;
    return true;
}

void ProcessStop(Process& p, int graceMs) {
    if (p <= 0) {
        p = kNoProcess;
        return;
    }

    for (int waited = 0; waited < graceMs; waited += 10) {
        int status = 0;
        const pid_t done = ::waitpid(p, &status, WNOHANG);
        if (done != 0) {
            p = kNoProcess;
            return;
        }
        ::usleep(10000);
    }

    ::kill(p, SIGKILL);
    int status = 0;
    ::waitpid(p, &status, 0);
    p = kNoProcess;
}

// Reaps the engine when it has ended; ProcessStop then finds nothing to wait
// for, which it already treats as done
bool ProcessExitCode(Process p, int waitMs, unsigned long& code) {
    if (p <= 0) return false;
    for (int waited = 0; ; waited += 10) {
        int status = 0;
        const pid_t done = ::waitpid(p, &status, WNOHANG);
        if (done == p) {
            if (WIFEXITED(status)) code = static_cast<unsigned long>(WEXITSTATUS(status));
            else if (WIFSIGNALED(status)) code = 128ul + static_cast<unsigned long>(WTERMSIG(status));
            else code = 0;
            return true;
        }
        if (done < 0 || waited >= waitMs) return false;
        ::usleep(10000);
    }
}

std::string ProcessExitText(unsigned long code) {
    if (code > 128ul && code < 128ul + 65ul)
        return std::string(kEngineName) + " was killed by signal " + std::to_string(code - 128ul);
    return std::string(kEngineName) + " exited with status " + std::to_string(code);
}

std::string ThisLibraryDir() {
    Dl_info info;
    if (::dladdr(reinterpret_cast<const void*>(&ThisLibraryDir), &info) == 0
        || info.dli_fname == nullptr) {
        return std::string();
    }
    const std::string self = info.dli_fname;
    const std::size_t cut = self.find_last_of('/');
    if (cut == std::string::npos) return std::string();
    return self.substr(0, cut);
}

bool Runnable(const std::string& path) {
    return !path.empty() && ::access(path.c_str(), X_OK) == 0;
}

std::string EngineOverride() {
    const char* named = std::getenv("STRATA_ENGINE");
    return (named != nullptr) ? named : "";
}

#endif

}  // namespace strata
