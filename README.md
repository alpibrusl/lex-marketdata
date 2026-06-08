# lex-marketdata

Market data types and reference data for Lex.

Defines the shared `Quote`, `Instrument`, and `Subscription` types used across the stack. The mock module provides deterministic canned quotes for testing and simulation — no network calls, no flaky tests.

**Current state:** `mock.lex` is hardcoded to 3 symbols (AAPL/MSFT/TSLA). A live feed adapter is tracked in [issue #1](https://github.com/alpibrusl/lex-marketdata/issues/1).

---

## Modules

### `quote.lex` — market data types

```lex
type Quote = { symbol :: Str, bid :: d.Decimal, ask :: d.Decimal, last :: d.Decimal, timestamp :: Str }
type MarketDataError = SymbolNotFound | StaleData | ConnectionError | MdParseError
```

`mid(quote)` and `spread(quote)` helpers.

### `mock.lex` — deterministic simulation (no effects)

```lex
import "lex-marketdata/src/mock" as mock

match mock.get_quote("AAPL") {
  Ok(q)  => # q.ask = $174.91  (hardcoded, deterministic)
  Err(_) => # symbol not in mock set — only AAPL, MSFT, TSLA
}
```

Used by `lex-oms` for margin and risk calculations in demo mode. Zero effects — every test run gets the same prices.

### `refdata.lex` — instrument reference data

```lex
type Instrument = { symbol :: Str, isin :: Str, cusip :: Str, lei :: Str,
                    name :: Str, currency :: ccy.Currency, exchange :: Str,
                    asset_class :: AssetClass }
type AssetClass = Equity | FixedIncome | Commodity | FX | Derivative | ETF
```

### `refdata_store.lex` — SQL-backed instrument store

`init`, `fetch`, `upsert`. Effects: `[sql]`.

### `market_data.lex` — subscription types

`Subscription` and `SubscriptionList` describe symbol subscriptions for a runtime feed adapter. Pure; the actual feed implementation is not yet in this repo.

---

## In the stack

```
lex-money
    ↓
lex-marketdata  ←  quotes and reference data
    ↓
lex-risk · lex-oms
```

`lex-risk` uses mark prices to compute notional and unrealized PnL. `lex-oms` uses `mock.get_reference_price` for margin pre-trade checks.

---

## What's next

A live feed adapter (`src/feed_polygon.lex`) would implement the same `get_quote` interface using a `[net, env]` call to Polygon.io. The type contract is already defined — only the implementation is missing. See [issue #1](https://github.com/alpibrusl/lex-marketdata/issues/1).

---

## Install

```toml
[dependencies]
"lex-marketdata" = { git = "https://github.com/alpibrusl/lex-marketdata" }
```
