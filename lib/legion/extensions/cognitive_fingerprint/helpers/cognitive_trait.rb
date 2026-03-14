# frozen_string_literal: true

module Legion
  module Extensions
    module CognitiveFingerprint
      module Helpers
        class CognitiveTrait
          attr_reader :id, :category, :baseline, :variance, :sample_count, :last_updated

          def initialize(category:)
            raise ArgumentError, "unknown category: #{category}" unless Constants::TRAIT_CATEGORIES.include?(category)

            @id           = SecureRandom.uuid
            @category     = category
            @baseline     = 0.5
            @variance     = 0.0
            @sample_count = 0
            @last_updated = Time.now.utc
          end

          def record_sample!(value)
            clamped = value.clamp(0.0, 1.0)
            old_baseline = @baseline
            @baseline = ((Constants::EMA_ALPHA * clamped) + ((1.0 - Constants::EMA_ALPHA) * old_baseline)).round(10)

            deviation = (clamped - @baseline).abs
            @variance = ((Constants::EMA_ALPHA * deviation) + ((1.0 - Constants::EMA_ALPHA) * @variance)).round(10)

            @sample_count = [@sample_count + 1, Constants::MAX_SAMPLES].min
            @last_updated = Time.now.utc
            self
          end

          def deviation_from(value)
            (value.clamp(0.0, 1.0) - @baseline).abs.round(10)
          end

          def stable?
            @variance <= 0.1
          end

          def volatile?
            @variance >= 0.3
          end

          def strength_label
            Constants.trait_strength_label_for(@baseline)
          end

          def to_h
            {
              id:           @id,
              category:     @category,
              baseline:     @baseline,
              variance:     @variance,
              sample_count: @sample_count,
              stable:       stable?,
              volatile:     volatile?,
              strength:     strength_label,
              last_updated: @last_updated
            }
          end
        end
      end
    end
  end
end
