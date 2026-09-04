#include "audio_plugin_demo/processor.hpp"

#include <array>
#include <cstddef>
#include <iostream>

auto main() -> int {
    static size_t constexpr kSampleCount = 4;
    std::array<float, kSampleCount> left{ 0.25F, -0.5F, 0.75F, -1.0F };
    std::array<float, kSampleCount> right{ -0.125F, 0.25F, -0.375F, 0.5F };
    std::array<float *, 2> channels{ left.data(), right.data() };

    td::audio_plugin_demo::Processor processor;
    if (!processor.Prepare(48'000.0, kSampleCount, channels.size()) || !processor.setGain(0.5F)) { return 1; }

    processor.ProcessBlock(td::audio_plugin_demo::AudioBlock{ channels, kSampleCount });

    std::cout << "Processed " << kSampleCount << " stereo frames at gain " << processor.getGain() << ":\n";
    for (size_t sample = 0; sample < kSampleCount; ++sample) {
        std::cout << "  [" << sample << "] left=" << left[sample] << ", right=" << right[sample] << '\n';
    }
    return 0;
}
