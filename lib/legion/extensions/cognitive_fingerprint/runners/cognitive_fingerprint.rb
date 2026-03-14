# frozen_string_literal: true

module Legion
  module Extensions
    module CognitiveFingerprint
      module Runners
        module CognitiveFingerprint
          include Legion::Extensions::Helpers::Lex if Legion::Extensions.const_defined?(:Helpers) &&
                                                      Legion::Extensions::Helpers.const_defined?(:Lex)

          def record_observation(category:, value:, **)
            category = category.to_sym
            result   = fingerprint_engine.record_observation(category: category, value: value.to_f)
            Legion::Logging.debug "[cognitive_fingerprint] record category=#{category} " \
                                  "baseline=#{result[:baseline]&.round(4)} samples=#{result[:samples]}"
            result
          end

          def verify_identity(observations:, **)
            parsed = Array(observations).map do |obs|
              { category: obs[:category].to_sym, value: obs[:value].to_f }
            end
            result = fingerprint_engine.verify_identity(observations: parsed)
            Legion::Logging.info "[cognitive_fingerprint] verify score=#{result[:match_score]&.round(4)} " \
                                 "verdict=#{result[:verdict]}"
            result
          end

          def anomaly_check(category:, value:, **)
            result = fingerprint_engine.anomaly_check(category: category.to_sym, value: value.to_f)
            if result[:anomaly]
              Legion::Logging.warn "[cognitive_fingerprint] anomaly category=#{category} " \
                                   "deviation=#{result[:deviation]&.round(4)}"
            end
            result
          end

          def trait_profile(**)
            { profile: fingerprint_engine.trait_profile }
          end

          def strongest_traits(n: 3, **)
            { traits: fingerprint_engine.strongest_traits(n.to_i) }
          end

          def weakest_traits(n: 3, **)
            { traits: fingerprint_engine.weakest_traits(n.to_i) }
          end

          def identity_confidence(**)
            confidence = fingerprint_engine.identity_confidence
            label      = fingerprint_engine.identity_label
            Legion::Logging.debug "[cognitive_fingerprint] confidence=#{confidence.round(4)} label=#{label}"
            { confidence: confidence, label: label }
          end

          def fingerprint_hash(**)
            { fingerprint_hash: fingerprint_engine.fingerprint_hash }
          end

          def fingerprint_report(**)
            fingerprint_engine.fingerprint_report
          end

          def fingerprint_status(**)
            {
              trait_count:  fingerprint_engine.trait_count,
              sample_count: fingerprint_engine.sample_count,
              label:        fingerprint_engine.identity_label
            }
          end

          private

          def fingerprint_engine
            @fingerprint_engine ||= Helpers::FingerprintEngine.new
          end
        end
      end
    end
  end
end
