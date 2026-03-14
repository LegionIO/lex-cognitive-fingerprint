# frozen_string_literal: true

module Legion
  module Extensions
    module CognitiveFingerprint
      module Helpers
        module Constants
          MAX_TRAITS   = 100
          MAX_SAMPLES  = 500
          EMA_ALPHA    = 0.15

          TRAIT_CATEGORIES = %i[
            processing_speed
            accuracy
            creativity
            caution
            thoroughness
            risk_tolerance
            abstraction_preference
            social_orientation
          ].freeze

          DEVIATION_THRESHOLD = 0.3

          IDENTITY_CONFIDENCE_LABELS = [
            { range: (0.85..1.0),  label: :certain },
            { range: (0.65...0.85), label: :confident },
            { range: (0.40...0.65), label: :developing },
            { range: (0.20...0.40), label: :uncertain },
            { range: (0.0...0.20),  label: :unknown }
          ].freeze

          TRAIT_STRENGTH_LABELS = [
            { range: (0.80..1.0),  label: :dominant },
            { range: (0.60...0.80), label: :strong },
            { range: (0.40...0.60), label: :moderate },
            { range: (0.20...0.40), label: :weak },
            { range: (0.0...0.20),  label: :absent }
          ].freeze

          module_function

          def identity_label_for(confidence)
            entry = IDENTITY_CONFIDENCE_LABELS.find { |e| e[:range].cover?(confidence) }
            entry ? entry[:label] : :unknown
          end

          def trait_strength_label_for(value)
            entry = TRAIT_STRENGTH_LABELS.find { |e| e[:range].cover?(value) }
            entry ? entry[:label] : :absent
          end
        end
      end
    end
  end
end
