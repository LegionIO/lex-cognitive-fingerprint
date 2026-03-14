# frozen_string_literal: true

require 'legion/extensions/cognitive_fingerprint/client'

RSpec.describe Legion::Extensions::CognitiveFingerprint::Runners::CognitiveFingerprint do
  let(:client) { Legion::Extensions::CognitiveFingerprint::Client.new }

  def seed_trait(category, value, n = 10)
    n.times { client.record_observation(category: category, value: value) }
  end

  describe '#record_observation' do
    it 'returns status :recorded for valid category' do
      result = client.record_observation(category: :accuracy, value: 0.7)
      expect(result[:status]).to eq(:recorded)
    end

    it 'accepts string category (coerced to symbol)' do
      result = client.record_observation(category: 'accuracy', value: 0.7)
      expect(result[:status]).to eq(:recorded)
    end

    it 'returns status :invalid_category for unknown category' do
      result = client.record_observation(category: :fake, value: 0.5)
      expect(result[:status]).to eq(:invalid_category)
    end

    it 'includes category in result' do
      result = client.record_observation(category: :creativity, value: 0.6)
      expect(result[:category]).to eq(:creativity)
    end

    it 'includes baseline in result' do
      result = client.record_observation(category: :caution, value: 0.4)
      expect(result[:baseline]).to be_a(Float)
    end

    it 'increments samples on repeated calls' do
      client.record_observation(category: :accuracy, value: 0.5)
      result = client.record_observation(category: :accuracy, value: 0.6)
      expect(result[:samples]).to eq(2)
    end
  end

  describe '#verify_identity' do
    context 'with matching observations' do
      before { seed_trait(:accuracy, 0.8) }

      it 'returns :verified for close observations' do
        result = client.verify_identity(observations: [{ category: :accuracy, value: 0.8 }])
        expect(result[:verdict]).to eq(:verified)
      end

      it 'returns match_score between 0 and 1' do
        result = client.verify_identity(observations: [{ category: :accuracy, value: 0.8 }])
        expect(result[:match_score]).to be_between(0.0, 1.0)
      end
    end

    context 'with mismatched observations' do
      before { seed_trait(:accuracy, 0.9, 20) }

      it 'returns :mismatch for large deviations' do
        result = client.verify_identity(observations: [{ category: :accuracy, value: 0.0 }])
        expect(result[:verdict]).to eq(:mismatch)
      end
    end

    it 'returns insufficient_data with no prior traits' do
      result = client.verify_identity(observations: [{ category: :accuracy, value: 0.5 }])
      expect(result[:verdict]).to eq(:insufficient_data)
    end

    it 'returns insufficient_data for empty observations list' do
      seed_trait(:accuracy, 0.7)
      result = client.verify_identity(observations: [])
      expect(result[:verdict]).to eq(:insufficient_data)
    end
  end

  describe '#anomaly_check' do
    it 'returns no_baseline when category has no data' do
      result = client.anomaly_check(category: :accuracy, value: 0.5)
      expect(result[:reason]).to eq(:no_baseline)
    end

    context 'with established baseline' do
      before { seed_trait(:accuracy, 0.8) }

      it 'returns anomaly: false for value near baseline' do
        result = client.anomaly_check(category: :accuracy, value: 0.8)
        expect(result[:anomaly]).to be false
      end

      it 'returns anomaly: true for outlier value' do
        result = client.anomaly_check(category: :accuracy, value: 0.0)
        expect(result[:anomaly]).to be true
      end

      it 'accepts string category' do
        result = client.anomaly_check(category: 'accuracy', value: 0.8)
        expect(result).to have_key(:anomaly)
      end
    end
  end

  describe '#trait_profile' do
    it 'returns empty profile initially' do
      result = client.trait_profile
      expect(result[:profile]).to eq({})
    end

    it 'returns profile with baselines after observations' do
      seed_trait(:accuracy, 0.7)
      seed_trait(:creativity, 0.4)
      profile = client.trait_profile[:profile]
      expect(profile).to have_key(:accuracy)
      expect(profile).to have_key(:creativity)
    end
  end

  describe '#strongest_traits' do
    before do
      seed_trait(:accuracy, 0.9)
      seed_trait(:creativity, 0.5)
      seed_trait(:caution, 0.2)
    end

    it 'returns top n traits by default' do
      result = client.strongest_traits
      expect(result[:traits].size).to be <= 3
    end

    it 'respects n keyword' do
      result = client.strongest_traits(n: 1)
      expect(result[:traits].size).to eq(1)
    end

    it 'sorted by baseline descending' do
      result = client.strongest_traits(n: 2)
      traits = result[:traits]
      expect(traits.first[:baseline]).to be >= traits.last[:baseline]
    end
  end

  describe '#weakest_traits' do
    before do
      seed_trait(:accuracy, 0.9)
      seed_trait(:creativity, 0.5)
      seed_trait(:caution, 0.2)
    end

    it 'returns bottom n traits' do
      result = client.weakest_traits
      expect(result[:traits].size).to be <= 3
    end

    it 'sorted by baseline ascending' do
      result = client.weakest_traits(n: 2)
      traits = result[:traits]
      expect(traits.first[:baseline]).to be <= traits.last[:baseline]
    end
  end

  describe '#identity_confidence' do
    it 'returns confidence: 0.0 with no traits' do
      result = client.identity_confidence
      expect(result[:confidence]).to eq(0.0)
    end

    it 'returns label: :unknown with no traits' do
      result = client.identity_confidence
      expect(result[:label]).to eq(:unknown)
    end

    it 'returns a valid label after observations' do
      seed_trait(:accuracy, 0.7)
      result = client.identity_confidence
      valid = %i[certain confident developing uncertain unknown]
      expect(valid).to include(result[:label])
    end

    it 'confidence is between 0 and 1' do
      seed_trait(:accuracy, 0.7)
      result = client.identity_confidence
      expect(result[:confidence]).to be_between(0.0, 1.0)
    end
  end

  describe '#fingerprint_hash' do
    it 'returns nil hash with no traits' do
      result = client.fingerprint_hash
      expect(result[:fingerprint_hash]).to be_nil
    end

    it 'returns a hex string after observations' do
      seed_trait(:accuracy, 0.7)
      result = client.fingerprint_hash
      expect(result[:fingerprint_hash]).to match(/\A[0-9a-f]{16}\z/)
    end
  end

  describe '#fingerprint_report' do
    it 'returns a complete report hash' do
      %i[fingerprint_hash identity_confidence identity_label trait_count sample_count traits].each do |key|
        expect(client.fingerprint_report).to have_key(key)
      end
    end

    it 'reflects accumulated observations' do
      seed_trait(:accuracy, 0.7)
      report = client.fingerprint_report
      expect(report[:trait_count]).to eq(1)
    end
  end

  describe '#fingerprint_status' do
    it 'returns trait_count, sample_count, label' do
      result = client.fingerprint_status
      expect(result).to have_key(:trait_count)
      expect(result).to have_key(:sample_count)
      expect(result).to have_key(:label)
    end

    it 'reflects current state' do
      seed_trait(:accuracy, 0.7)
      result = client.fingerprint_status
      expect(result[:trait_count]).to eq(1)
      expect(result[:sample_count]).to eq(10)
    end
  end
end
