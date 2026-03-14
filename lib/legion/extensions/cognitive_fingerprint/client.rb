# frozen_string_literal: true

require 'legion/extensions/cognitive_fingerprint/helpers/constants'
require 'legion/extensions/cognitive_fingerprint/helpers/cognitive_trait'
require 'legion/extensions/cognitive_fingerprint/helpers/fingerprint_engine'
require 'legion/extensions/cognitive_fingerprint/runners/cognitive_fingerprint'

module Legion
  module Extensions
    module CognitiveFingerprint
      class Client
        include Runners::CognitiveFingerprint

        def initialize(**)
          @fingerprint_engine = Helpers::FingerprintEngine.new
        end

        private

        attr_reader :fingerprint_engine
      end
    end
  end
end
