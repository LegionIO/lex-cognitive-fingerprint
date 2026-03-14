# frozen_string_literal: true

module Legion
  module Extensions
    module CognitiveFingerprint
      module Helpers
        class FingerprintEngine
          attr_reader :samples

          def initialize
            @traits  = {}
            @samples = []
          end

          def record_observation(category:, value:)
            return { status: :invalid_category, category: category } unless Constants::TRAIT_CATEGORIES.include?(category)

            trait = get_or_create_trait(category)
            trait.record_sample!(value.clamp(0.0, 1.0))

            @samples << { category: category, value: value.clamp(0.0, 1.0), recorded_at: Time.now.utc }
            @samples.shift while @samples.size > Constants::MAX_SAMPLES

            {
              status:   :recorded,
              category: category,
              baseline: trait.baseline,
              variance: trait.variance,
              samples:  trait.sample_count
            }
          end

          def verify_identity(observations:)
            return { match_score: 0.0, verdict: :insufficient_data } if observations.empty? || @traits.empty?

            scored = score_observations(observations)
            return { match_score: 0.0, verdict: :insufficient_data } if scored.empty?

            score = (scored.sum / scored.size).round(10)
            { match_score: score, verdict: score_verdict(score), observations_checked: scored.size }
          end

          def trait_profile
            @traits.transform_values(&:baseline)
          end

          def strongest_traits(top_n = 3)
            @traits.values
                   .sort_by { |t| -t.baseline }
                   .first(top_n)
                   .map(&:to_h)
          end

          def weakest_traits(top_n = 3)
            @traits.values
                   .sort_by(&:baseline)
                   .first(top_n)
                   .map(&:to_h)
          end

          def identity_confidence
            return 0.0 if @traits.empty?

            stable_count = @traits.values.count(&:stable?)
            sampled      = @traits.values.select { |t| t.sample_count.positive? }
            return 0.0 if sampled.empty?

            coverage  = sampled.size.to_f / Constants::TRAIT_CATEGORIES.size
            stability = stable_count.to_f / @traits.size

            ((coverage * 0.6) + (stability * 0.4)).round(10).clamp(0.0, 1.0)
          end

          def identity_label
            Constants.identity_label_for(identity_confidence)
          end

          def anomaly_check(category:, value:)
            trait = @traits[category]
            return { anomaly: false, reason: :no_baseline } unless trait

            dev     = trait.deviation_from(value.clamp(0.0, 1.0))
            anomaly = dev >= Constants::DEVIATION_THRESHOLD
            {
              anomaly:   anomaly,
              category:  category,
              value:     value.clamp(0.0, 1.0),
              baseline:  trait.baseline,
              deviation: dev.round(10),
              threshold: Constants::DEVIATION_THRESHOLD
            }
          end

          def fingerprint_hash
            return nil if @traits.empty?

            profile_string = Constants::TRAIT_CATEGORIES.map do |cat|
              t = @traits[cat]
              t ? "#{cat}:#{t.baseline.round(6)}" : "#{cat}:nil"
            end.join('|')

            require 'digest'
            ::Digest::SHA256.hexdigest(profile_string)[0, 16]
          end

          def trait_count
            @traits.size
          end

          def sample_count
            @samples.size
          end

          def fingerprint_report
            {
              fingerprint_hash:    fingerprint_hash,
              identity_confidence: identity_confidence,
              identity_label:      identity_label,
              trait_count:         trait_count,
              sample_count:        @samples.size,
              traits:              @traits.transform_values(&:to_h)
            }
          end

          def to_h
            fingerprint_report
          end

          private

          def score_observations(observations)
            observations.filter_map do |obs|
              cat   = obs[:category]
              val   = obs[:value]
              trait = @traits[cat]
              next unless trait && Constants::TRAIT_CATEGORIES.include?(cat)

              dev = trait.deviation_from(val.clamp(0.0, 1.0))
              [1.0 - (dev / [Constants::DEVIATION_THRESHOLD, 0.001].max), 0.0].max.clamp(0.0, 1.0)
            end
          end

          def score_verdict(score)
            if score >= 0.7
              :verified
            elsif score >= 0.4
              :uncertain
            else
              :mismatch
            end
          end

          def get_or_create_trait(category)
            @traits[category] ||= CognitiveTrait.new(category: category)
            if @traits.size > Constants::MAX_TRAITS
              oldest_key = @traits.min_by { |_, t| t.last_updated }.first
              @traits.delete(oldest_key)
            end
            @traits[category]
          end
        end
      end
    end
  end
end
