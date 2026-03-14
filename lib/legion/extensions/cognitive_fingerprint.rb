# frozen_string_literal: true

require 'legion/extensions/cognitive_fingerprint/version'
require 'legion/extensions/cognitive_fingerprint/helpers/constants'
require 'legion/extensions/cognitive_fingerprint/helpers/cognitive_trait'
require 'legion/extensions/cognitive_fingerprint/helpers/fingerprint_engine'
require 'legion/extensions/cognitive_fingerprint/runners/cognitive_fingerprint'

module Legion
  module Extensions
    module CognitiveFingerprint
      extend Legion::Extensions::Core if Legion::Extensions.const_defined? :Core
    end
  end
end
