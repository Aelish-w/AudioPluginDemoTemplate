# Audio Plugin Demo Template

A small C++23 starting point for experimenting with audio DSP before coupling it to a particular plug-in framework or
format. The core library has no dependency on JUCE, iPlug2, VST3, Audio Units, CLAP, or a host SDK. A framework adapter
can translate its audio-buffer type into `td::audio_plugin_demo::AudioBlock` without bringing framework types into the DSP
code.

The included processor is intentionally simple: it applies a bounded linear gain to caller-owned, non-interleaved
floating-point channels. Replace that operation with the DSP being demonstrated while retaining the processing
contract.

## Build and test

The development preset selects the Clang/LLVM toolchain and enables sanitizers and static checks:

```sh
cmake --preset clang
cmake --build --preset clang
ctest --test-dir out/build/clang --output-on-failure
```

Use `cmake --build --preset clang-checks` to run formatting, clang-tidy, the Clang static analyzer, filename checks, and
header-guard checks. A release build is available through `cmake --preset clang-release` and
`cmake --build --preset clang-release`.

## Processing contract

- Call `Processor::Prepare` after the sample rate, maximum block size, or channel count changes. Call `Reset` after a
  transport discontinuity or before reusing a processor. Neither function may run concurrently with `ProcessBlock`.
- `AudioBlock` is a non-owning view. Its channel pointers and samples must remain valid for the duration of
  `ProcessBlock`.
- `ProcessBlock` is `noexcept` and performs no allocation, locking, I/O, or unbounded work. Invalid block dimensions are
  rejected without touching the audio.
- Gain updates use an always-lock-free atomic and become visible at block boundaries. A 20 ms linear ramp is owned by
  the audio thread, so parameter changes are smoothed without locks or shared mutable smoothing state.
- Plug-in adapters should perform bus-layout validation and turn host parameter values into bounded DSP parameters
  before entering the processing callback.

## Layout

- `include/audio_plugin_demo/processor.hpp`: public framework-neutral API.
- `src/processor.cpp`: compiled DSP implementation.
- `demo/main.cpp`: deterministic standalone example.
- `tests/processor_test.cpp`: dependency-free unit test registered with CTest.
- `cmake/`: reusable naming, header-guard, and Clang toolchain support.

When starting a new demo, rename the project, namespace, include directory, target prefix, CMake option prefix, and
header guards together. Keep framework-specific processor/editor code in a separate adapter target so the DSP core and
its tests stay fast and portable.
