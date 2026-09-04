#ifndef AUDIO_PLUGIN_DEMO_PROCESSOR_HPP
#define AUDIO_PLUGIN_DEMO_PROCESSOR_HPP

#include <atomic>
#include <cstddef>
#include <span>

namespace td::audio_plugin_demo {


    class AudioBlock {
     public:
        constexpr AudioBlock(std::span<float *const> channels, size_t const sample_count) noexcept
            : channels_{ channels }, sample_count_{ sample_count } {}

        [[nodiscard]] constexpr auto getChannels() const noexcept -> std::span<float *const> { return channels_; }

        [[nodiscard]] constexpr auto getSampleCount() const noexcept -> size_t { return sample_count_; }

     private:
        std::span<float *const> channels_;
        size_t sample_count_{};
    };

    class Processor final {
     public:
        static float constexpr kMinimumGain               = 0.0F;
        static float constexpr kMaximumGain               = 2.0F;
        static double constexpr kGainSmoothingTimeSeconds = 0.02;

        [[nodiscard]] auto Prepare(double sample_rate, size_t maximum_block_size, size_t channel_count) noexcept
            -> bool;

        auto Reset() noexcept -> void;

        [[nodiscard]] auto setGain(float gain) noexcept -> bool;

        [[nodiscard]] auto getGain() const noexcept -> float;

        auto ProcessBlock(AudioBlock block) noexcept -> void;

     private:
        static_assert(std::atomic<float>::is_always_lock_free,
                      "the gain parameter must be lock-free on the audio thread");

        std::atomic<float> target_gain_{ 1.0F };
        float current_gain_{ 1.0F };
        float smoothing_increment_{};
        float smoothing_target_{ 1.0F };
        size_t smoothing_length_samples_{ 1 };
        size_t smoothing_samples_remaining_{};
        size_t maximum_block_size_{};
        size_t channel_count_{};
        bool prepared_{};
    };


} // namespace td::audio_plugin_demo

#endif // AUDIO_PLUGIN_DEMO_PROCESSOR_HPP
