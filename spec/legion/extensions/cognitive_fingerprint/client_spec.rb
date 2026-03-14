# frozen_string_literal: true

require 'legion/extensions/cognitive_fingerprint/client'

RSpec.describe Legion::Extensions::CognitiveFingerprint::Client do
  let(:client) { described_class.new }

  it 'responds to record_observation' do
    expect(client).to respond_to(:record_observation)
  end

  it 'responds to verify_identity' do
    expect(client).to respond_to(:verify_identity)
  end

  it 'responds to anomaly_check' do
    expect(client).to respond_to(:anomaly_check)
  end

  it 'responds to trait_profile' do
    expect(client).to respond_to(:trait_profile)
  end

  it 'responds to strongest_traits' do
    expect(client).to respond_to(:strongest_traits)
  end

  it 'responds to weakest_traits' do
    expect(client).to respond_to(:weakest_traits)
  end

  it 'responds to identity_confidence' do
    expect(client).to respond_to(:identity_confidence)
  end

  it 'responds to fingerprint_hash' do
    expect(client).to respond_to(:fingerprint_hash)
  end

  it 'responds to fingerprint_report' do
    expect(client).to respond_to(:fingerprint_report)
  end

  it 'responds to fingerprint_status' do
    expect(client).to respond_to(:fingerprint_status)
  end

  it 'each instance has independent state' do
    c1 = described_class.new
    c2 = described_class.new
    c1.record_observation(category: :accuracy, value: 0.9)
    expect(c2.fingerprint_status[:trait_count]).to eq(0)
  end
end
