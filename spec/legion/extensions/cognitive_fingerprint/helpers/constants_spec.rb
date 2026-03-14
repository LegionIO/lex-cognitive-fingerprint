# frozen_string_literal: true

RSpec.describe Legion::Extensions::CognitiveFingerprint::Helpers::Constants do
  describe 'TRAIT_CATEGORIES' do
    it 'contains 8 categories' do
      expect(described_class::TRAIT_CATEGORIES.size).to eq(8)
    end

    it 'includes all expected categories' do
      expect(described_class::TRAIT_CATEGORIES).to include(
        :processing_speed, :accuracy, :creativity, :caution,
        :thoroughness, :risk_tolerance, :abstraction_preference, :social_orientation
      )
    end

    it 'is frozen' do
      expect(described_class::TRAIT_CATEGORIES).to be_frozen
    end
  end

  describe 'MAX_TRAITS' do
    it 'equals 100' do
      expect(described_class::MAX_TRAITS).to eq(100)
    end
  end

  describe 'MAX_SAMPLES' do
    it 'equals 500' do
      expect(described_class::MAX_SAMPLES).to eq(500)
    end
  end

  describe 'EMA_ALPHA' do
    it 'equals 0.15' do
      expect(described_class::EMA_ALPHA).to eq(0.15)
    end
  end

  describe 'DEVIATION_THRESHOLD' do
    it 'equals 0.3' do
      expect(described_class::DEVIATION_THRESHOLD).to eq(0.3)
    end
  end

  describe '.identity_label_for' do
    it 'returns :certain for high confidence' do
      expect(described_class.identity_label_for(0.9)).to eq(:certain)
    end

    it 'returns :certain at exactly 0.85' do
      expect(described_class.identity_label_for(0.85)).to eq(:certain)
    end

    it 'returns :confident for 0.65-0.85 range' do
      expect(described_class.identity_label_for(0.75)).to eq(:confident)
    end

    it 'returns :developing for 0.40-0.65 range' do
      expect(described_class.identity_label_for(0.5)).to eq(:developing)
    end

    it 'returns :uncertain for 0.20-0.40 range' do
      expect(described_class.identity_label_for(0.3)).to eq(:uncertain)
    end

    it 'returns :unknown for low confidence' do
      expect(described_class.identity_label_for(0.1)).to eq(:unknown)
    end

    it 'returns :unknown for exactly 0.0' do
      expect(described_class.identity_label_for(0.0)).to eq(:unknown)
    end

    it 'returns :certain for exactly 1.0' do
      expect(described_class.identity_label_for(1.0)).to eq(:certain)
    end
  end

  describe '.trait_strength_label_for' do
    it 'returns :dominant for high values' do
      expect(described_class.trait_strength_label_for(0.9)).to eq(:dominant)
    end

    it 'returns :dominant at exactly 0.80' do
      expect(described_class.trait_strength_label_for(0.80)).to eq(:dominant)
    end

    it 'returns :strong for 0.60-0.80 range' do
      expect(described_class.trait_strength_label_for(0.7)).to eq(:strong)
    end

    it 'returns :moderate for 0.40-0.60 range' do
      expect(described_class.trait_strength_label_for(0.5)).to eq(:moderate)
    end

    it 'returns :weak for 0.20-0.40 range' do
      expect(described_class.trait_strength_label_for(0.3)).to eq(:weak)
    end

    it 'returns :absent for low values' do
      expect(described_class.trait_strength_label_for(0.1)).to eq(:absent)
    end

    it 'returns :absent for 0.0' do
      expect(described_class.trait_strength_label_for(0.0)).to eq(:absent)
    end
  end
end
