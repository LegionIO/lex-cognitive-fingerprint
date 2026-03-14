# lex-cognitive-fingerprint

Behavioral fingerprinting and identity verification for cognitive entities in the LegionIO ecosystem.

## What It Does

Builds a stable behavioral fingerprint by recording observations across eight trait dimensions: processing_speed, accuracy, creativity, caution, thoroughness, risk_tolerance, abstraction_preference, and social_orientation. Each observation updates a per-trait Exponential Moving Average baseline. Once a profile is established, identity verification compares a new set of observations against the fingerprint and returns a match score and verdict. Single-observation anomaly detection flags deviations that exceed the deviation threshold.

The fingerprint hash is a 16-character SHA256 derived from all trait baselines, providing a compact comparison key.

## Usage

```ruby
require 'legion/extensions/cognitive_fingerprint'

client = Legion::Extensions::CognitiveFingerprint::Client.new

# Build a fingerprint by recording observations
client.record_observation(category: :accuracy, value: 0.85)
client.record_observation(category: :caution, value: 0.72)
client.record_observation(category: :creativity, value: 0.60)

# Check identity confidence once enough observations are recorded
client.identity_confidence
# => { confidence: 0.24, label: :uncertain }

# Verify identity against a set of new observations
client.verify_identity(observations: [
  { category: :accuracy,   value: 0.83 },
  { category: :caution,    value: 0.75 }
])
# => { match_score: 0.93, verdict: :verified, observations_checked: 2 }

# Check single-observation anomaly
client.anomaly_check(category: :accuracy, value: 0.1)
# => { anomaly: true, deviation: 0.75, threshold: 0.3, ... }
```

## Development

```bash
bundle install
bundle exec rspec
bundle exec rubocop
```

## License

MIT
