#include "audio_plugin_demo/processor.hpp"

#include <atomic>
#include <cmath>
#include <cstddef>
#include <limits>

namespace td::audio_plugin_demo {


    auto Processor::Prepare(double const sample_rate,
                            size_t const maximum_block_size,
                            size_t const channel_count) noexcept -> bool {
        if (!std::isfinite(sample_rate) || sample_rate <= 0.0 || maximum_block_size == 0 || channel_count == 0) {
            prepared_ = false;
            return false;
        }

        double const smoothing_length = std::ceil(sample_rate * kGainSmoothingTimeSeconds);
        if (smoothing_length >= static_cast<double>(std::numeric_limits<size_t>::max())) {
            prepared_ = false;
            return false;
        }

        smoothing_length_samples_ = static_cast<size_t>(smoothing_length);
        maximum_block_size_       = maximum_block_size;
        channel_count_            = channel_count;
        prepared_                 = true;
        Reset();
        return true;
    }

    auto Processor::Reset() noexcept -> void {
        current_gain_                = target_gain_.load(std::memory_order_relaxed);
        smoothing_target_            = current_gain_;
        smoothing_increment_         = 0.0F;
        smoothing_samples_remaining_ = 0;
    }

    auto Processor::setGain(float const gain) noexcept -> bool {
        if (!std::isfinite(gain) || gain < kMinimumGain || gain > kMaximumGain) { return false; }

        target_gain_.store(gain, std::memory_order_relaxed);
        return true;
    }

    auto Processor::getGain() const noexcept -> float { return target_gain_.load(std::memory_order_relaxed); }

    auto Processor::ProcessBlock(AudioBlock const block) noexcept -> void {
        auto const channels       = block.getChannels();
        size_t const sample_count = block.getSampleCount();
        if (!prepared_ || channels.size() > channel_count_ || sample_count > maximum_block_size_) { return; }

        for (float const *const channel : channels) {
            if (channel == nullptr && sample_count != 0) { return; }
        }

        float const target_gain = target_gain_.load(std::memory_order_relaxed);
        if (target_gain != smoothing_target_) {
            smoothing_target_            = target_gain;
            smoothing_samples_remaining_ = smoothing_length_samples_;
            smoothing_increment_ = (smoothing_target_ - current_gain_) / static_cast<float>(smoothing_length_samples_);
        }

        for (size_t sample = 0; sample < sample_count; ++sample) {
            if (smoothing_samples_remaining_ != 0) {
                current_gain_ += smoothing_increment_;
                --smoothing_samples_remaining_;
                if (smoothing_samples_remaining_ == 0) { current_gain_ = smoothing_target_; }
            }

            for (float *const channel : channels) { channel[sample] *= current_gain_; }
        }
    }


} // namespace td::audio_plugin_demo
