#----------------------------------------------------------------------------
# Setup the project
cmake_minimum_required(VERSION 3.17 FATAL_ERROR)
project(Strata VERSION 1.0.0)

#----------------------------------------------------------------------------
# Find Geant4 package, activating all available UI and Vis drivers by default
# You can set WITH_GEANT4_UIVIS to OFF via the command line or ccmake/cmake-gui
# to build a batch mode only executable
#
option(WITH_GEANT4_UIVIS "Build Strata with Geant4 UI and Vis drivers" ON)

# Qt 6.8 links AGL, which recent macOS SDKs no longer have
if (APPLE)
    set(WrapOpenGL_AGL "-framework OpenGL" CACHE STRING "")
endif ()
if (WITH_GEANT4_UIVIS)
    find_package(Geant4 REQUIRED ui_all vis_all)
else ()
    find_package(Geant4 REQUIRED HINTS)
endif ()

if (Geant4_FOUND)
    message(STATUS "Geant4 v${Geant4_VERSION} found!")
    message(STATUS "Geant4 include dirs: ${Geant4_INCLUDE_DIRS}")
    message(STATUS "Geant4 definitions: ${Geant4_DEFINITIONS}")
    message(STATUS "Flags used to compile Geant4: ${Geant4_CXX_FLAGS}")
    message(STATUS "Geant4 libraries: ${Geant4_LIBRARIES}")
endif()

# Link only what Strata uses, so Qt and Xerces come from Geant4 alone
if (APPLE)
    add_link_options(LINKER:-dead_strip_dylibs)
endif ()

# Check if datasets can be located
message(STATUS "Geant4 datasets:")
foreach(dsname ${Geant4_DATASETS})  # Iterate over dataset names
    message(STATUS "Path to '${dsname}': ${Geant4_DATASET_${dsname}_PATH}")
    message(STATUS "Env var '${Geant4_DATASET_${dsname}_ENVVAR}': $ENV{${Geant4_DATASET_${dsname}_ENVVAR}}")
    if(NOT EXISTS ${Geant4_DATASET_${dsname}_PATH})  # Check existence
        if(NOT EXISTS $ENV{${Geant4_DATASET_${dsname}_ENVVAR}})  # Check existence of environment variable
            message(WARNING "${dsname} not located neither at the dataset path ${Geant4_DATASET_${dsname}_PATH} \
                             nor at the path set in the environment variable $ENV{${Geant4_DATASET_${dsname}_ENVVAR}}")
        endif()
    endif()
endforeach()

#----------------------------------------------------------------------------
# Setup Geant4 include directories and compile definitions
#
include(${Geant4_USE_FILE})

#----------------------------------------------------------------------------
# Locate sources and headers for this project
#
include_directories(${PROJECT_SOURCE_DIR}/include
        ${Geant4_INCLUDE_DIR})
# CONFIGURE_DEPENDS makes the build tool re-run the glob before every build.
# Without it the file list is fixed when the build directory is configured,
# so a source file added afterwards (by a patch, or by a branch switch)
# is silently left out and only shows up as an undefined symbol at link
# time.  It costs one directory scan per build.
file(GLOB sources CONFIGURE_DEPENDS ${PROJECT_SOURCE_DIR}/src/*.cc)
file(GLOB headers CONFIGURE_DEPENDS ${PROJECT_SOURCE_DIR}/include/*.hh)

#----------------------------------------------------------------------------
# The physics code is compiled once, into an object library, and reused by
# both the stand-alone executable and the shared library that the Lazarus
# front end loads.  Position-independent code is required for the latter.
#
add_library(StrataCore OBJECT ${sources} ${headers})
set_target_properties(StrataCore PROPERTIES POSITION_INDEPENDENT_CODE ON)
target_link_libraries(StrataCore PUBLIC ${Geant4_LIBRARIES})

#----------------------------------------------------------------------------
# Add the executable, and link it to the Geant4 libraries
#
add_executable(Strata Strata.cc $<TARGET_OBJECTS:StrataCore>)
target_link_libraries(Strata ${Geant4_LIBRARIES})

#----------------------------------------------------------------------------
# strata_dedx: tabulates Geant4's electronic stopping power in the format
# /strata/physics/srim/loadTable reads, and checks a loaded table against
# what the 'srim' physics list then computes.
#
add_executable(strata_dedx tools/strata_dedx.cc $<TARGET_OBJECTS:StrataCore>)
target_link_libraries(strata_dedx ${Geant4_LIBRARIES})
install(TARGETS strata_dedx DESTINATION bin)

# strata_rbs_check: the RBS kinematics and cross-section, checked against
# the same quantities derived a second way through the centre of mass.
add_executable(strata_rbs_check tools/strata_rbs_check.cc $<TARGET_OBJECTS:StrataCore>)
target_link_libraries(strata_rbs_check ${Geant4_LIBRARIES})

# strata_dpa_check: the NRT and arc-dpa displacement counts, against the
# thresholds and limits of the paper the constants come from.
add_executable(strata_dpa_check tools/strata_dpa_check.cc $<TARGET_OBJECTS:StrataCore>)
target_link_libraries(strata_dpa_check ${Geant4_LIBRARIES})

#----------------------------------------------------------------------------
# Shared library exposing the flat C API (api/strata_api.h).  This is what
# the Free Pascal / Lazarus front end loads at run time; symbols are hidden
# by default so that only the strata_* entry points are exported.
#
option(STRATA_BUILD_SHARED "Build the libstrata shared library for the GUI" ON)

if (STRATA_BUILD_SHARED)
    # The target is called libstrata, which is also the name of the file it
    # produces, so an IDE listing targets shows the library under the name
    # everything else calls it.  It cannot simply be "strata": the executable
    # target is "Strata", and on a case-insensitive filesystem (the macOS
    # and Windows default) targets "strata" and "Strata" share one
    # CMakeFiles/<target>.dir directory.  The Makefile generator writes
    # build.make, depend.make and DependInfo.cmake per target, so the second
    # one generated silently overwrites the first's and the build dies with
    #     No rule to make target 'CMakeFiles/Strata.dir/depend'
    # Ninja survives that only because it keeps a single build.ninja.
    #
    # OUTPUT_NAME keeps the file libstrata.so / .dylib / strata.dll rather
    # than liblibstrata.
    # Geant4 runs in the engine process, so the library the front end loads
    # is the client half of the protocol and links no Geant4 at all.
    add_library(libstrata SHARED api/strata_client.cc api/strata_protocol.cc
                api/strata_pipe.cc)
    target_include_directories(libstrata PUBLIC ${PROJECT_SOURCE_DIR}/api)
    # Without this the header is read as dllimport while the DLL is built
    target_compile_definitions(libstrata PRIVATE STRATA_BUILDING_DLL)
    # Windows has no run path, so the engine finds the Geant4 DLLs through
    # its PATH.  The client puts the bin directory of the Geant4 this was
    # built against on the engine's PATH, after its own directory and
    # %STRATA_GEANT4_DIR%\bin, which is what makes a build tree run without
    # Geant4 on the system PATH; a directory that has since gone is skipped
    if (WIN32)
        get_filename_component(_strata_g4_bindir "${Geant4_DIR}/../../../bin" ABSOLUTE)
        if (EXISTS "${_strata_g4_bindir}")
            message(STATUS "Engine PATH falls back on ${_strata_g4_bindir}")
            target_compile_definitions(libstrata PRIVATE
                    STRATA_GEANT4_BINDIR="${_strata_g4_bindir}")
        endif ()
    endif ()
    set_target_properties(libstrata PROPERTIES
            OUTPUT_NAME strata
            POSITION_INDEPENDENT_CODE ON
            CXX_VISIBILITY_PRESET hidden
            VISIBILITY_INLINES_HIDDEN ON
            VERSION 1.0.0
            SOVERSION 1
            PUBLIC_HEADER ${PROJECT_SOURCE_DIR}/api/strata_api.h)
    install(TARGETS libstrata
            LIBRARY DESTINATION lib
            PUBLIC_HEADER DESTINATION include/strata)

    # Small C driver used by the test suite to exercise the ABI exactly the
    # way the Pascal binding does: load, configure, run, read results back.
    add_executable(strata_smoke api/strata_smoke.c)
    target_link_libraries(strata_smoke libstrata)

    # More than one engine in one front end, and surviving one that is not
    # there.
    add_executable(strata_restart_check api/strata_restart_check.c)
    target_link_libraries(strata_restart_check libstrata)
endif ()

#----------------------------------------------------------------------------
# The engine process: strata_api.h on one side, two pipes on the other.  This
# is where Geant4 lives.
add_executable(strata_engine api/strata_server.cc api/strata_protocol.cc
               api/strata_pipe.cc api/strata_api.cc $<TARGET_OBJECTS:StrataCore>)
target_include_directories(strata_engine PRIVATE ${PROJECT_SOURCE_DIR}/api)
# The engine defines the entry points rather than importing them
target_compile_definitions(strata_engine PRIVATE STRATA_BUILDING_DLL)
target_link_libraries(strata_engine ${Geant4_LIBRARIES})
install(TARGETS strata_engine DESTINATION bin)

#----------------------------------------------------------------------------
# Copy all macros to the build directory, i.e. the directory in which we
# build Strata. This is so that we can run the executable directly because it
# relies on these macros being in the 'macros' folder, inside the current
# working directory.
#
file(GLOB Strata_SCRIPTS CONFIGURE_DEPENDS ${PROJECT_SOURCE_DIR}/macros/*.mac)

foreach (_script ${Strata_SCRIPTS})
    get_filename_component(MACRO_NAME ${_script} NAME)
    configure_file(
            ${_script}
            ${PROJECT_BINARY_DIR}/macros/${MACRO_NAME}
            COPYONLY
    )
endforeach ()

#----------------------------------------------------------------------------
# Copy python script to the build directory
#
configure_file(plotHisto.py ${PROJECT_BINARY_DIR}/plotHisto.py COPYONLY)

#----------------------------------------------------------------------------
# Where the Geant4 libraries are looked for at run time.
#
# An installed Strata finds Geant4 beside itself or where the Geant4 installers put it
#
if (APPLE)
    set(_strata_origin "@loader_path")
    set(_strata_g4_lib "/usr/local/geant4/${Geant4_VERSION}/lib")
else ()
    set(_strata_origin "$ORIGIN")
    set(_strata_g4_lib "/opt/geant4/${Geant4_VERSION}/lib")
endif ()
set(STRATA_GEANT4_LIBDIR "${_strata_g4_lib}" CACHE PATH "Where an installed Strata looks for Geant4")
set(_strata_rpath "${_strata_origin};${_strata_origin}/../lib;${STRATA_GEANT4_LIBDIR};${Geant4_DIR}/../..")

set(_strata_installed Strata strata_engine)
if (STRATA_BUILD_SHARED)
    list(APPEND _strata_installed libstrata)
endif ()
set_target_properties(${_strata_installed} PROPERTIES
        BUILD_WITH_INSTALL_RPATH FALSE
        INSTALL_RPATH "${_strata_rpath}"
        INSTALL_RPATH_USE_LINK_PATH FALSE)

#----------------------------------------------------------------------------
# Install the executable to 'bin' directory under CMAKE_INSTALL_PREFIX
#
install(TARGETS Strata DESTINATION bin)

