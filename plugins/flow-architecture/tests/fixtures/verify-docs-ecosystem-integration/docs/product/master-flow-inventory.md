---
last_reviewed: 2026-05-26
---

# Master flow inventory — fixture project

Minimal inventory stub used by the BC-11091 integration test. One domain, one sub-flow — the minimum surface `regenerate-flow-index.mts` accepts (it refuses to regenerate against zero domains or zero parseable story docs).

The domain code is UPPERCASE `FX` to match `regenerate-flow-index.mts` `parseDomainOrder`'s `[A-Z]+` capture group. The fixture format intentionally mirrors `regenerate-flow-index.mts`'s parser shape rather than the BC-10352 lowercase-backtick canonical, because the fixture exists to exercise `regenerate-flow-index.sh --check` (not the classifier).

### FX — Fixture Domain (1 flows)

| Flow ID | Title | Status |
|---|---|---|
| FX-1 | placeholder sub-flow | not-started |
