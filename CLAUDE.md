# lex-cognitive-fingerprint

**Level 3 Leaf Documentation**
- **Parent**: `/Users/miverso2/rubymine/legion/extensions-agentic/CLAUDE.md`
- **Gem**: `lex-cognitive-fingerprint`

## Purpose

Builds and maintains a behavioral fingerprint for a cognitive entity across eight trait categories. Observations are recorded against categories using Exponential Moving Average (EMA) to establish stable baselines. Identity verification compares a set of observations against baselines to produce a match score and verdict. Anomaly detection flags single observations that deviate significantly from baseline.

## Gem Info

| Field | Value |
|---|---|
| Gem name | `lex-cognitive-fingerprint` |
| Version | `0.1.0` |
| Namespace | `Legion::Extensions::CognitiveFingerprint` |
| Ruby | `>= 3.4` |
| License | MIT |
| GitHub | https://github.com/LegionIO/lex-cognitive-fingerprint |

## File Structure

```
lib/legion/extensions/cognitive_fingerprint/
  cognitive_fingerprint.rb          # Top-level require
  version.rb                        # VERSION = '0.1.0'
  client.rb                         # Client class
  helpers/
    constants.rb                    # Trait categories, EMA alpha, label arrays
    cognitive_trait.rb              # CognitiveTrait EMA tracker
    fingerprint_engine.rb           # Engine: trait map, samples, verification
  runners/
    cognitive_fingerprint.rb        # Runner module
```

## Key Constants

| Constant | Value | Meaning |
|---|---|---|
| `MAX_TRAITS` | 100 | Maximum traits tracked (LRU eviction on oldest) |
| `MAX_SAMPLES` | 500 | Sample history ring buffer |
| `EMA_ALPHA` | 0.15 | EMA smoothing factor for trait baseline updates |
| `TRAIT_CATEGORIES` | array | `processing_speed`, `accuracy`, `creativity`, `caution`, `thoroughness`, `risk_tolerance`, `abstraction_preference`, `social_orientation` |
| `DEVIATION_THRESHOLD` | 0.3 | Deviation above this triggers anomaly |
| `IDENTITY_CONFIDENCE_LABELS` | array | `certain` (0.85+), `confident`, `developing`, `uncertain`, `unknown` |
| `TRAIT_STRENGTH_LABELS` | array | `dominant` (0.80+), `strong`, `moderate`, `weak`, `absent` |

## Helpers

### `CognitiveTrait`

EMA tracker for a single trait category.

- `record_sample!(value)` — updates `baseline` via EMA with `EMA_ALPHA`; increments `sample_count`
- `variance` — variance of recent samples
- `stable?` — boolean based on variance threshold
- `deviation_from(value)` — absolute distance from baseline
- `last_updated` — for LRU eviction ordering
- `to_h`

### `FingerprintEngine`

Owns trait map and sample history.

- `record_observation(category:, value:)` — validates category; creates/updates trait via EMA; appends to samples ring buffer; returns `:recorded` status with baseline and sample count
- `verify_identity(observations:)` — compares array of `{ category:, value: }` against baselines; scores each as `1.0 - (deviation / DEVIATION_THRESHOLD)`, returns mean `match_score` and verdict (`:verified` / `:uncertain` / `:mismatch`)
- `anomaly_check(category:, value:)` — single-observation deviation check; returns `{ anomaly:, deviation: }`
- `trait_profile` — hash of category → baseline
- `strongest_traits(top_n)`, `weakest_traits(top_n)`
- `identity_confidence` — coverage × 0.6 + stability × 0.4
- `identity_label` — resolves from `IDENTITY_CONFIDENCE_LABELS`
- `fingerprint_hash` — SHA256 of `cat:baseline|...` profile string, first 16 chars
- `fingerprint_report` — complete report including hash, confidence, all traits

## Runners

**Module**: `Legion::Extensions::CognitiveFingerprint::Runners::CognitiveFingerprint`

| Method | Key Args | Returns |
|---|---|---|
| `record_observation` | `category:`, `value:` | `{ status:, baseline:, samples: }` |
| `verify_identity` | `observations:` | `{ match_score:, verdict: }` |
| `anomaly_check` | `category:`, `value:` | `{ anomaly:, deviation:, threshold: }` |
| `trait_profile` | — | `{ profile: { category => baseline } }` |
| `strongest_traits` | `top_n: 3` | `{ traits: [...] }` |
| `weakest_traits` | `top_n: 3` | `{ traits: [...] }` |
| `identity_confidence` | — | `{ confidence:, label: }` |
| `fingerprint_hash` | — | `{ fingerprint_hash: }` |
| `fingerprint_report` | — | Full report hash |
| `fingerprint_status` | — | `{ trait_count:, sample_count:, label: }` |

Private: `fingerprint_engine` — memoized `FingerprintEngine`.

## Integration Points

- **`lex-identity`**: `lex-identity` tracks behavioral dimensions via EMA for a *human partner*. `lex-cognitive-fingerprint` tracks trait baselines for any cognitive entity. Both use EMA; they serve complementary but distinct purposes.
- **`lex-tick`**: `anomaly_check` results could feed the `identity_entropy_check` phase as a supplementary signal.
- **`lex-trust`**: Identity mismatch from `verify_identity` could trigger trust penalties in `lex-trust`.

## Development Notes

- `verify_identity` scores `:insufficient_data` when no trained traits exist or no observations are provided.
- LRU eviction on `MAX_TRAITS`: the trait with the oldest `last_updated` is removed to make room, then the new trait is inserted. This means a short burst of many new categories can silently evict established ones.
- `fingerprint_hash` returns `nil` when the trait map is empty.
- All values are clamped to `[0.0, 1.0]` on input.

---

**Maintained By**: Matthew Iverson (@Esity)
