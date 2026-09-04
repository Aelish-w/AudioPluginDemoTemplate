#include "audio_plugin_demo/processor.hpp"

#include <array>
#include <cstddef>
#include <iostream>
#include <limits>

namespace {


    auto Expect(bool const condition, char const *const message) -> bool {
        if (condition) { return true; }

        std::cerr << "FAILED: " << message << '\n';
        return false;
    }

    auto TestPreparationValidation() -> bool {
        td::audio_plugin_demo::Processor processor;
        bool passed  = true;
        passed      &= Expect(!processor.Prepare(std::numeric_limits<double>::quiet_NaN(), 64, 2),
                              "Prepare rejects a non-finite sample rate");
        passed      &= Expect(!processor.Prepare(48'000.0, 0, 2), "Prepare rejects an empty maximum block");
        passed      &= Expect(!processor.Prepare(48'000.0, 64, 0), "Prepare rejects zero channels");
        passed      &= Expect(processor.Prepare(48'000.0, 64, 2), "Prepare accepts a valid processing specification");
        return passed;
    }

    auto TestGainValidation() -> bool {
        td::audio_plugin_demo::Processor processor;
        bool passed  = true;
        passed      &= Expect(!processor.setGain(-0.01F), "setGain rejects negative gain");
        passed      &= Expect(!processor.setGain(td::audio_plugin_demo::Processor::kMaximumGain + 0.01F),
                              "setGain rejects gain above the supported range");
        passed &= Expect(!processor.setGain(std::numeric_limits<float>::infinity()), "setGain rejects non-finite gain");
        passed &= Expect(processor.setGain(0.5F), "setGain accepts a valid gain");
        passed &= Expect(processor.getGain() == 0.5F, "getGain returns the most recent valid gain");
        return passed;
    }

    auto TestStereoProcessing() -> bool {
        static size_t constexpr kSampleCount = 5;
        std::array<float, kSampleCount> left{ 1.0F, 0.5F, 0.0F, -0.5F, -1.0F };
        std::array<float, kSampleCount> right{ -0.25F, -0.125F, 0.0F, 0.125F, 0.25F };
        std::array<float *, 2> channels{ left.data(), right.data() };

        td::audio_plugin_demo::Processor processor;
        bool passed  = true;
        passed      &= Expect(processor.setGain(0.5F), "test gain is valid");
        passed      &= Expect(processor.Prepare(48'000.0, kSampleCount, channels.size()),
                              "processor prepares for the test block");
        processor.ProcessBlock(td::audio_plugin_demo::AudioBlock{ channels, kSampleCount });

        static std::array<float, kSampleCount> constexpr kExpectedLeft{ 0.5F, 0.25F, 0.0F, -0.25F, -0.5F };
        static std::array<float, kSampleCount> constexpr kExpectedRight{ -0.125F, -0.0625F, 0.0F, 0.0625F, 0.125F };
        passed &= Expect(left == kExpectedLeft, "left channel is multiplied by the configured gain");
        passed &= Expect(right == kExpectedRight, "right channel is multiplied by the configured gain");
        return passed;
    }

    auto TestGainSmoothing() -> bool {
        static size_t constexpr kSmoothingSamples = 20;
        std::array<float, kSmoothingSamples> samples{};
        samples.fill(1.0F);
        std::array<float *, 1> channels{ samples.data() };

        td::audio_plugin_demo::Processor processor;
        bool passed  = true;
        passed      &= Expect(processor.Prepare(1'000.0, kSmoothingSamples, channels.size()),
                              "processor prepares with a 20-sample smoothing interval");
        passed      &= Expect(processor.setGain(0.0F), "smoothing target is valid");
        processor.ProcessBlock(td::audio_plugin_demo::AudioBlock{ channels, kSmoothingSamples });

        passed &= Expect(samples.front() > samples.back(), "gain decreases across the smoothing interval");
        passed &= Expect(samples.front() < 1.0F, "smoothing begins on the first processed sample");
        passed &= Expect(samples.back() == 0.0F, "gain reaches its target at the end of the smoothing interval");
        return passed;
    }


} // namespace

auto main() -> int {
    bool const passed = TestPreparationValidation() &&
                        TestGainValidation() &&
                        TestStereoProcessing() &&
                        TestGainSmoothing();
    if (!passed) { return 1; }

    std::cout << "All processor tests passed\n";
    return 0;
}
