# lex-marketdata

Market data types and reference data for the [Lex language](https://github.com/alpibrusl/lex-lang).

Defines the shared types used across market-data consumers. The mock module provides deterministic quote values for tests and simulation without any live-feed effects. The `Subscription` / `SubscriptionList` types describe symbol subscriptions for a runtime adapter.

## What it ships

- **`src/quote.lex`** — `Quote` (`symbol`, `bid`, `ask`, `last`, `timestamp`), `MarketDataError` (`SymbolNotFound` / `StaleData` / `ConnectionError` / `MdParseError`), `mid` and `spread` helpers.
- **`src/market_data.lex`** — `Subscription` and `SubscriptionList` types for runtime subscription configuration. Pure; the actual feed adapter lives at the server layer.
- **`src/refdata.lex`** — `Instrument` (`symbol`, `isin`, `cusip`, `lei`, `name`, `currency`, `exchange`, `asset_class`), `AssetClass` ADT, `RefDataError`.
- **`src/refdata_store.lex`** — SQL-backed instrument store (`init`, `fetch`, `upsert`). Effects: `[sql]`.
- **`src/mock.lex`** — Pure canned quotes for AAPL (174.91), MSFT (418.51), TSLA (172.41). `get_quote(symbol)` and `get_reference_price(symbol)` with no effects. Used by lex-oms for margin and risk calculations in demo mode.

## Usage

```lex
import "lex-marketdata/src/mock" as mock

match mock.get_reference_price("AAPL") {
  Err(_) => # symbol not in mock set
  Ok(p)  => # p is a Decimal (e.g. { coefficient: 17491, exponent: -2 })
}
```

## Effects

`quote.lex`, `market_data.lex`, `refdata.lex`, `mock.lex` — none (pure). `refdata_store.lex` — `[sql]`.

## Dependencies

- **lex-money** — `Decimal` for bid/ask/last prices.
- **lex-orm** — SQL connection for `refdata_store.lex`.

---

Built under the principles of [Trust Without Comprehension](https://alpibru.com/manifesto).
