//
// ********************************************************************
// * Strata: a Geant4 application for ion irradiation of layered       *
// * targets.                                                          *
// ********************************************************************
//
// \file Strata/api/strata_pipe.hh
// \brief The one place that knows how a process and a pipe are made.
//
// Everything platform-specific in the engine transport lives here, so that
// the client, the server and the protocol are the same source everywhere.

#ifndef STRATA_PIPE_HH
#define STRATA_PIPE_HH

#include <cstddef>
#include <string>

namespace strata {

#ifdef _WIN32
using Pipe = void*;              // HANDLE
using Process = void*;           // HANDLE
#else
using Pipe = int;                // file descriptor
using Process = int;             // pid_t
#endif

extern const Pipe kNoPipe;
extern const Process kNoProcess;

// The name the engine is installed under
extern const char* const kEngineName;

// The two ends of one pipe: which the front end keeps, which the engine gets
struct PipeEnds {
    Pipe parent = kNoPipe;
    Pipe child = kNoPipe;
};

bool PipePair(PipeEnds& ends, bool parentWrites);
void PipeClose(Pipe& p);
bool PipeWriteAll(Pipe p, const void* data, std::size_t n);
bool PipeReadAll(Pipe p, void* data, std::size_t n);

// How an end is named to the engine, and how the engine reads it back
std::string PipeToText(Pipe p);
Pipe PipeFromText(const char* text);

bool ProcessStart(const std::string& path, const PipeEnds& toChild, const PipeEnds& fromChild, Process& out);

// Waits AGraceMs for the engine to leave on its own, then insists
void ProcessStop(Process& p, int graceMs);

// Once the pipes have broken: whether the engine has ended, waiting up to
// AWaitMs for it, and with what code.  The process is not reaped here, so
// ProcessStop is still to be called
bool ProcessExitCode(Process p, int waitMs, unsigned long& code);

// What an exit code says about why the engine went, for an error message
std::string ProcessExitText(unsigned long code);

// Where this library itself sits, empty when it cannot be found
std::string ThisLibraryDir();
bool Runnable(const std::string& path);

// STRATA_ENGINE, empty when it is not set
std::string EngineOverride();

}  // namespace strata

#endif  // STRATA_PIPE_HH
