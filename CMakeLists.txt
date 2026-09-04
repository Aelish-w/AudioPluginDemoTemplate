cmake_minimum_required(VERSION 3.25)

project(AudioPluginDemoTemplate VERSION 0.1.0 LANGUAGES CXX)

set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

option(AUDIO_PLUGIN_DEMO_ENABLE_CLANG_TOOLS "Enable clang-tidy, formatting, and analyzer targets" OFF)
option(AUDIO_PLUGIN_DEMO_ENABLE_SANITIZERS "Enable address and undefined-behavior sanitizers" OFF)
option(AUDIO_PLUGIN_DEMO_WARNINGS_AS_ERRORS "Treat compiler warnings as errors" OFF)

include(CTest)
include(cmake/check_file_names.cmake)
check_file_names(ROOT "${PROJECT_SOURCE_DIR}")

set(AUDIO_PLUGIN_DEMO_PUBLIC_HEADERS
    include/audio_plugin_demo/processor.hpp
)
set(AUDIO_PLUGIN_DEMO_CORE_SOURCES
    src/processor.cpp
)
set(AUDIO_PLUGIN_DEMO_DEMO_SOURCES
    demo/main.cpp
)
set(AUDIO_PLUGIN_DEMO_TEST_SOURCES
    tests/processor_test.cpp
)
set(AUDIO_PLUGIN_DEMO_ALL_SOURCES
    ${AUDIO_PLUGIN_DEMO_PUBLIC_HEADERS}
    ${AUDIO_PLUGIN_DEMO_CORE_SOURCES}
    ${AUDIO_PLUGIN_DEMO_DEMO_SOURCES}
    ${AUDIO_PLUGIN_DEMO_TEST_SOURCES}
)
set(AUDIO_PLUGIN_DEMO_TRANSLATION_UNITS
    ${AUDIO_PLUGIN_DEMO_CORE_SOURCES}
    ${AUDIO_PLUGIN_DEMO_DEMO_SOURCES}
)

add_library(audio_plugin_demo_core STATIC ${AUDIO_PLUGIN_DEMO_CORE_SOURCES})
add_library(audio_plugin_demo::core ALIAS audio_plugin_demo_core)
target_sources(
    audio_plugin_demo_core
    PUBLIC
        FILE_SET HEADERS
        BASE_DIRS "${PROJECT_SOURCE_DIR}/include"
        FILES ${AUDIO_PLUGIN_DEMO_PUBLIC_HEADERS}
)
target_include_directories(
    audio_plugin_demo_core
    PUBLIC "$<BUILD_INTERFACE:${PROJECT_SOURCE_DIR}/include>"
)
target_compile_features(audio_plugin_demo_core PUBLIC cxx_std_23)

add_executable(audio_plugin_demo ${AUDIO_PLUGIN_DEMO_DEMO_SOURCES})
target_link_libraries(audio_plugin_demo PRIVATE audio_plugin_demo::core)

set(AUDIO_PLUGIN_DEMO_TARGETS
    audio_plugin_demo_core
    audio_plugin_demo
)

if(BUILD_TESTING)
    add_executable(audio_plugin_demo_test ${AUDIO_PLUGIN_DEMO_TEST_SOURCES})
    target_link_libraries(audio_plugin_demo_test PRIVATE audio_plugin_demo::core)
    add_test(NAME audio_plugin_demo_test COMMAND audio_plugin_demo_test)

    list(APPEND AUDIO_PLUGIN_DEMO_TARGETS audio_plugin_demo_test)
    list(APPEND AUDIO_PLUGIN_DEMO_TRANSLATION_UNITS ${AUDIO_PLUGIN_DEMO_TEST_SOURCES})
endif()

foreach(_audio_plugin_demo_target IN LISTS AUDIO_PLUGIN_DEMO_TARGETS)
    set_target_properties(${_audio_plugin_demo_target} PROPERTIES CXX_EXTENSIONS OFF)
    target_compile_options(
        ${_audio_plugin_demo_target}
        PRIVATE
            "$<$<COMPILE_LANG_AND_ID:CXX,Clang,AppleClang,GNU>:-Wall;-Wextra;-Wpedantic;-Wconversion;-Wsign-conversion;-Wshadow;-Wundef>"
            "$<$<COMPILE_LANG_AND_ID:CXX,MSVC>:/W4;/permissive->"
    )

    if(AUDIO_PLUGIN_DEMO_WARNINGS_AS_ERRORS)
        target_compile_options(
            ${_audio_plugin_demo_target}
            PRIVATE
                "$<$<COMPILE_LANG_AND_ID:CXX,Clang,AppleClang,GNU>:-Werror>"
                "$<$<COMPILE_LANG_AND_ID:CXX,MSVC>:/WX>"
        )
    endif()

    if(AUDIO_PLUGIN_DEMO_ENABLE_SANITIZERS)
        target_compile_options(
            ${_audio_plugin_demo_target}
            PRIVATE -fsanitize=address,undefined -fno-omit-frame-pointer
        )
        target_link_options(
            ${_audio_plugin_demo_target}
            PRIVATE -fsanitize=address,undefined -fno-omit-frame-pointer
        )
    endif()
endforeach()

if(AUDIO_PLUGIN_DEMO_ENABLE_SANITIZERS AND NOT CMAKE_CXX_COMPILER_ID MATCHES "^(Apple)?Clang|GNU$")
    message(FATAL_ERROR "AUDIO_PLUGIN_DEMO_ENABLE_SANITIZERS requires Clang, AppleClang, or GCC")
endif()

add_custom_target(
    check-file-names
    COMMAND
        "${CMAKE_COMMAND}"
        "-DPROJECT_ROOT=${PROJECT_SOURCE_DIR}"
        -P "${PROJECT_SOURCE_DIR}/cmake/check_file_names.cmake"
    COMMENT "Checking project file names"
    VERBATIM
)

add_custom_target(
    check-header-guards
    COMMAND
        "${CMAKE_COMMAND}"
        "-DPROJECT_ROOT=${PROJECT_SOURCE_DIR}"
        "-DHEADERS=${AUDIO_PLUGIN_DEMO_PUBLIC_HEADERS}"
        -P "${PROJECT_SOURCE_DIR}/cmake/check_header_guards.cmake"
    WORKING_DIRECTORY "${PROJECT_SOURCE_DIR}"
    COMMENT "Checking traditional header guards"
    VERBATIM
)

add_custom_target(
    check-source-conventions
    DEPENDS check-file-names check-header-guards
)

foreach(_audio_plugin_demo_target IN LISTS AUDIO_PLUGIN_DEMO_TARGETS)
    add_dependencies(${_audio_plugin_demo_target} check-source-conventions)
endforeach()

if(AUDIO_PLUGIN_DEMO_ENABLE_CLANG_TOOLS)
    if(NOT CMAKE_CXX_COMPILER_ID STREQUAL "Clang" OR CMAKE_CXX_COMPILER_VERSION VERSION_LESS 22.1)
        message(FATAL_ERROR "Clang tools require LLVM Clang 22.1 or later; configure with --preset clang")
    endif()

    find_program(AUDIO_PLUGIN_DEMO_CLANG_FORMAT NAMES clang-format clang-format-22 REQUIRED)
    find_program(AUDIO_PLUGIN_DEMO_CLANG_TIDY NAMES clang-tidy clang-tidy-22 REQUIRED)

    foreach(_audio_plugin_demo_target IN LISTS AUDIO_PLUGIN_DEMO_TARGETS)
        set_property(
            TARGET ${_audio_plugin_demo_target}
            PROPERTY CXX_CLANG_TIDY "${AUDIO_PLUGIN_DEMO_CLANG_TIDY};--experimental-custom-checks"
        )
    endforeach()

    add_custom_target(
        format
        COMMAND
            "${AUDIO_PLUGIN_DEMO_CLANG_FORMAT}"
            -i
            --style=file
            ${AUDIO_PLUGIN_DEMO_ALL_SOURCES}
        WORKING_DIRECTORY "${PROJECT_SOURCE_DIR}"
        COMMENT "Formatting C++ sources"
        VERBATIM
    )

    add_custom_target(
        format-check
        COMMAND
            "${AUDIO_PLUGIN_DEMO_CLANG_FORMAT}"
            --dry-run
            --Werror
            --style=file
            ${AUDIO_PLUGIN_DEMO_ALL_SOURCES}
        WORKING_DIRECTORY "${PROJECT_SOURCE_DIR}"
        COMMENT "Checking C++ formatting"
        VERBATIM
    )

    add_custom_target(
        clang-tidy
        COMMAND
            "${AUDIO_PLUGIN_DEMO_CLANG_TIDY}"
            --experimental-custom-checks
            -p "${PROJECT_BINARY_DIR}"
            ${AUDIO_PLUGIN_DEMO_TRANSLATION_UNITS}
        WORKING_DIRECTORY "${PROJECT_SOURCE_DIR}"
        COMMENT "Running clang-tidy"
        VERBATIM
    )

    add_custom_target(
        clang-analyze
        COMMAND
            "${AUDIO_PLUGIN_DEMO_CLANG_TIDY}"
            --experimental-custom-checks
            "--checks=-*,clang-analyzer-*"
            "--warnings-as-errors=clang-analyzer-*"
            -p "${PROJECT_BINARY_DIR}"
            ${AUDIO_PLUGIN_DEMO_TRANSLATION_UNITS}
        WORKING_DIRECTORY "${PROJECT_SOURCE_DIR}"
        COMMENT "Running the Clang static analyzer"
        VERBATIM
    )

    add_custom_target(
        clang-checks
        DEPENDS format-check clang-tidy clang-analyze check-source-conventions
    )
endif()
