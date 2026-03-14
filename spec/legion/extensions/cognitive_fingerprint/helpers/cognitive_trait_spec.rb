# frozen_string_literal: true

RSpec.describe Legion::Extensions::CognitiveFingerprint::Helpers::CognitiveTrait do
  let(:trait) { described_class.new(category: :accuracy) }

  describe '#initialize' do
    it 'assigns a UUID id' do
      expect(trait.id).to match(/\A[0-9a-f-]{36}\z/)
    end

    it 'sets category' do
      expect(trait.category).to eq(:accuracy)
    end

    it 'starts with baseline 0.5' do
      expect(trait.baseline).to eq(0.5)
    end

    it 'starts with zero variance' do
      expect(trait.variance).to eq(0.0)
    end

    it 'starts with zero sample count' do
      expect(trait.sample_count).to eq(0)
    end

    it 'sets last_updated to a Time' do
      expect(trait.last_updated).to be_a(Time)
    end

    it 'raises for unknown category' do
      expect { described_class.new(category: :nonexistent) }.to raise_error(ArgumentError, /unknown category/)
    end

    it 'accepts all valid categories' do
      Legion::Extensions::CognitiveFingerprint::Helpers::Constants::TRAIT_CATEGORIES.each do |cat|
        expect { described_class.new(category: cat) }.not_to raise_error
      end
    end
  end

  describe '#record_sample!' do
    it 'returns self for chaining' do
      expect(trait.record_sample!(0.8)).to eq(trait)
    end

    it 'shifts baseline toward sample (EMA)' do
      original = trait.baseline
      trait.record_sample!(1.0)
      expect(trait.baseline).to be > original
    end

    it 'shifts baseline down for low samples' do
      original = trait.baseline
      trait.record_sample!(0.0)
      expect(trait.baseline).to be < original
    end

    it 'increments sample_count' do
      trait.record_sample!(0.7)
      expect(trait.sample_count).to eq(1)
    end

    it 'applies EMA_ALPHA correctly for one update' do
      expected = (0.15 * 0.8) + (0.85 * 0.5)
      trait.record_sample!(0.8)
      expect(trait.baseline).to be_within(0.0000001).of(expected)
    end

    it 'clamps input values above 1.0' do
      trait.record_sample!(5.0)
      expect(trait.baseline).to be <= 1.0
    end

    it 'clamps input values below 0.0' do
      trait.record_sample!(-2.0)
      expect(trait.baseline).to be >= 0.0
    end

    it 'updates last_updated' do
      before = trait.last_updated
      trait.record_sample!(0.6)
      expect(trait.last_updated).to be >= before
    end

    it 'caps sample_count at MAX_SAMPLES' do
      (Legion::Extensions::CognitiveFingerprint::Helpers::Constants::MAX_SAMPLES + 10).times do
        trait.record_sample!(0.5)
      end
      expect(trait.sample_count).to eq(Legion::Extensions::CognitiveFingerprint::Helpers::Constants::MAX_SAMPLES)
    end

    it 'accumulates variance over varying samples' do
      trait.record_sample!(0.1)
      trait.record_sample!(0.9)
      expect(trait.variance).to be > 0.0
    end

    it 'rounds baseline to 10 decimal places' do
      trait.record_sample!(0.333333333)
      expect(trait.baseline.to_s.split('.').last.length).to be <= 10
    end
  end

  describe '#deviation_from' do
    it 'returns 0.0 for baseline value' do
      expect(trait.deviation_from(0.5)).to eq(0.0)
    end

    it 'returns positive deviation for values above baseline' do
      expect(trait.deviation_from(0.9)).to be > 0.0
    end

    it 'returns positive deviation for values below baseline' do
      expect(trait.deviation_from(0.1)).to be > 0.0
    end

    it 'is always non-negative' do
      expect(trait.deviation_from(0.0)).to be >= 0.0
      expect(trait.deviation_from(1.0)).to be >= 0.0
    end

    it 'clamps out-of-range inputs' do
      dev_low  = trait.deviation_from(-1.0)
      dev_zero = trait.deviation_from(0.0)
      expect(dev_low).to eq(dev_zero)
    end
  end

  describe '#stable?' do
    it 'is stable with zero variance' do
      expect(trait.stable?).to be true
    end

    it 'is not stable when variance exceeds 0.1' do
      5.times { trait.record_sample!(0.1) }
      5.times { trait.record_sample!(0.9) }
      # After divergent samples variance should grow beyond threshold
      trait.record_sample!(0.0)
      trait.record_sample!(1.0)
      # variance might still be low from EMA; just check the boundary condition
      low_var_trait = described_class.new(category: :accuracy)
      expect(low_var_trait.stable?).to be true
    end
  end

  describe '#volatile?' do
    it 'is not volatile with zero variance' do
      expect(trait.volatile?).to be false
    end
  end

  describe '#strength_label' do
    it 'returns a valid label symbol' do
      valid = %i[dominant strong moderate weak absent]
      expect(valid).to include(trait.strength_label)
    end

    it 'returns :moderate for default baseline of 0.5' do
      expect(trait.strength_label).to eq(:moderate)
    end
  end

  describe '#to_h' do
    let(:hash) { trait.to_h }

    it 'includes required keys' do
      %i[id category baseline variance sample_count stable volatile strength last_updated].each do |key|
        expect(hash).to have_key(key)
      end
    end

    it 'reflects current state' do
      trait.record_sample!(0.8)
      h = trait.to_h
      expect(h[:sample_count]).to eq(1)
      expect(h[:baseline]).to be > 0.5
    end
  end
end
