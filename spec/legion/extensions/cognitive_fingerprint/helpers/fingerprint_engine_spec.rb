# frozen_string_literal: true

RSpec.describe Legion::Extensions::CognitiveFingerprint::Helpers::FingerprintEngine do
  let(:engine) { described_class.new }

  def observe(category, value)
    engine.record_observation(category: category, value: value)
  end

  describe '#record_observation' do
    it 'returns status :recorded for valid category' do
      result = observe(:accuracy, 0.8)
      expect(result[:status]).to eq(:recorded)
    end

    it 'returns status :invalid_category for unknown category' do
      result = observe(:nonexistent, 0.5)
      expect(result[:status]).to eq(:invalid_category)
    end

    it 'stores trait on first observation' do
      observe(:accuracy, 0.7)
      expect(engine.trait_count).to eq(1)
    end

    it 'returns baseline after observation' do
      result = observe(:creativity, 0.8)
      expect(result[:baseline]).to be > 0.0
    end

    it 'increments samples on each call' do
      observe(:accuracy, 0.5)
      observe(:accuracy, 0.7)
      result = observe(:accuracy, 0.6)
      expect(result[:samples]).to eq(3)
    end

    it 'clamps values above 1.0' do
      result = observe(:accuracy, 5.0)
      expect(result[:baseline]).to be <= 1.0
    end

    it 'clamps values below 0.0' do
      result = observe(:accuracy, -1.0)
      expect(result[:baseline]).to be >= 0.0
    end

    it 'accumulates global sample log' do
      observe(:accuracy, 0.5)
      observe(:creativity, 0.6)
      expect(engine.sample_count).to eq(2)
    end

    it 'caps global samples at MAX_SAMPLES' do
      max = Legion::Extensions::CognitiveFingerprint::Helpers::Constants::MAX_SAMPLES
      (max + 20).times { observe(:accuracy, 0.5) }
      expect(engine.sample_count).to eq(max)
    end
  end

  describe '#verify_identity' do
    context 'with no traits built' do
      it 'returns insufficient_data verdict' do
        result = engine.verify_identity(observations: [{ category: :accuracy, value: 0.8 }])
        expect(result[:verdict]).to eq(:insufficient_data)
      end
    end

    context 'with observations that match baseline' do
      before do
        10.times { observe(:accuracy, 0.8) }
        10.times { observe(:creativity, 0.6) }
      end

      it 'returns :verified for matching observations' do
        result = engine.verify_identity(observations: [
                                          { category: :accuracy, value: 0.8 },
                                          { category: :creativity, value: 0.6 }
                                        ])
        expect(result[:verdict]).to eq(:verified)
      end

      it 'returns a match_score between 0 and 1' do
        result = engine.verify_identity(observations: [{ category: :accuracy, value: 0.8 }])
        expect(result[:match_score]).to be_between(0.0, 1.0)
      end

      it 'returns observations_checked count' do
        result = engine.verify_identity(observations: [
                                          { category: :accuracy, value: 0.8 },
                                          { category: :creativity, value: 0.6 }
                                        ])
        expect(result[:observations_checked]).to eq(2)
      end
    end

    context 'with mismatched observations' do
      before { 20.times { observe(:accuracy, 0.8) } }

      it 'returns :mismatch for very deviant observations' do
        result = engine.verify_identity(observations: [{ category: :accuracy, value: 0.0 }])
        expect(result[:verdict]).to eq(:mismatch)
      end
    end

    it 'returns insufficient_data for empty observations' do
      observe(:accuracy, 0.5)
      result = engine.verify_identity(observations: [])
      expect(result[:verdict]).to eq(:insufficient_data)
    end

    it 'skips observations for unknown categories' do
      observe(:accuracy, 0.5)
      result = engine.verify_identity(observations: [{ category: :unknown_cat, value: 0.5 }])
      expect(result[:verdict]).to eq(:insufficient_data)
    end
  end

  describe '#trait_profile' do
    it 'returns empty hash when no traits' do
      expect(engine.trait_profile).to eq({})
    end

    it 'returns category => baseline mapping' do
      observe(:accuracy, 0.8)
      observe(:creativity, 0.4)
      profile = engine.trait_profile
      expect(profile).to have_key(:accuracy)
      expect(profile).to have_key(:creativity)
    end

    it 'values are floats between 0 and 1' do
      observe(:caution, 0.7)
      engine.trait_profile.each_value do |v|
        expect(v).to be_between(0.0, 1.0)
      end
    end
  end

  describe '#strongest_traits' do
    before do
      observe(:accuracy, 0.9)
      observe(:creativity, 0.5)
      observe(:caution, 0.1)
    end

    it 'returns traits sorted by baseline descending' do
      strongest = engine.strongest_traits(2)
      expect(strongest.first[:baseline]).to be >= strongest.last[:baseline]
    end

    it 'respects n parameter' do
      expect(engine.strongest_traits(1).size).to eq(1)
    end

    it 'returns hashes with required keys' do
      traits = engine.strongest_traits(1)
      expect(traits.first).to have_key(:category)
      expect(traits.first).to have_key(:baseline)
    end
  end

  describe '#weakest_traits' do
    before do
      observe(:accuracy, 0.9)
      observe(:creativity, 0.5)
      observe(:caution, 0.1)
    end

    it 'returns traits sorted by baseline ascending' do
      weakest = engine.weakest_traits(2)
      expect(weakest.first[:baseline]).to be <= weakest.last[:baseline]
    end

    it 'respects n parameter' do
      expect(engine.weakest_traits(1).size).to eq(1)
    end
  end

  describe '#identity_confidence' do
    it 'returns 0.0 with no traits' do
      expect(engine.identity_confidence).to eq(0.0)
    end

    it 'returns a value between 0 and 1 with data' do
      observe(:accuracy, 0.7)
      expect(engine.identity_confidence).to be_between(0.0, 1.0)
    end

    it 'increases as more categories are covered' do
      conf1 = engine.identity_confidence
      observe(:accuracy, 0.7)
      conf2 = engine.identity_confidence
      observe(:creativity, 0.6)
      conf3 = engine.identity_confidence
      expect(conf3).to be >= conf2
      expect(conf2).to be >= conf1
    end
  end

  describe '#identity_label' do
    it 'returns :unknown with no traits' do
      expect(engine.identity_label).to eq(:unknown)
    end

    it 'returns a valid confidence label' do
      observe(:accuracy, 0.7)
      valid = %i[certain confident developing uncertain unknown]
      expect(valid).to include(engine.identity_label)
    end
  end

  describe '#anomaly_check' do
    context 'with no baseline' do
      it 'returns anomaly: false and reason: :no_baseline' do
        result = engine.anomaly_check(category: :accuracy, value: 0.5)
        expect(result[:anomaly]).to be false
        expect(result[:reason]).to eq(:no_baseline)
      end
    end

    context 'with established baseline' do
      before { 10.times { observe(:accuracy, 0.8) } }

      it 'returns anomaly: false for value near baseline' do
        result = engine.anomaly_check(category: :accuracy, value: 0.8)
        expect(result[:anomaly]).to be false
      end

      it 'returns anomaly: true for value far from baseline' do
        result = engine.anomaly_check(category: :accuracy, value: 0.0)
        expect(result[:anomaly]).to be true
      end

      it 'includes deviation in result' do
        result = engine.anomaly_check(category: :accuracy, value: 0.5)
        expect(result[:deviation]).to be >= 0.0
      end

      it 'includes baseline in result' do
        result = engine.anomaly_check(category: :accuracy, value: 0.5)
        expect(result[:baseline]).to be > 0.0
      end

      it 'includes threshold in result' do
        result = engine.anomaly_check(category: :accuracy, value: 0.5)
        expect(result[:threshold]).to eq(0.3)
      end
    end
  end

  describe '#fingerprint_hash' do
    it 'returns nil with no traits' do
      expect(engine.fingerprint_hash).to be_nil
    end

    it 'returns a 16-char hex string with data' do
      observe(:accuracy, 0.7)
      expect(engine.fingerprint_hash).to match(/\A[0-9a-f]{16}\z/)
    end

    it 'is deterministic for same baseline values' do
      observe(:accuracy, 0.7)
      h1 = engine.fingerprint_hash
      h2 = engine.fingerprint_hash
      expect(h1).to eq(h2)
    end

    it 'changes when baseline changes meaningfully' do
      observe(:accuracy, 0.5)
      h1 = engine.fingerprint_hash
      20.times { observe(:accuracy, 1.0) }
      h2 = engine.fingerprint_hash
      expect(h1).not_to eq(h2)
    end
  end

  describe '#fingerprint_report' do
    it 'returns a hash with required keys' do
      %i[fingerprint_hash identity_confidence identity_label trait_count sample_count traits].each do |key|
        expect(engine.fingerprint_report).to have_key(key)
      end
    end

    it 'reflects accumulated state' do
      observe(:accuracy, 0.7)
      observe(:creativity, 0.5)
      report = engine.fingerprint_report
      expect(report[:trait_count]).to eq(2)
      expect(report[:sample_count]).to eq(2)
    end
  end

  describe '#to_h' do
    it 'delegates to fingerprint_report' do
      observe(:accuracy, 0.7)
      expect(engine.to_h).to eq(engine.fingerprint_report)
    end
  end

  describe '#trait_count' do
    it 'returns 0 initially' do
      expect(engine.trait_count).to eq(0)
    end

    it 'counts unique categories' do
      observe(:accuracy, 0.5)
      observe(:creativity, 0.5)
      expect(engine.trait_count).to eq(2)
    end

    it 'does not double-count same category' do
      observe(:accuracy, 0.5)
      observe(:accuracy, 0.7)
      expect(engine.trait_count).to eq(1)
    end
  end
end
