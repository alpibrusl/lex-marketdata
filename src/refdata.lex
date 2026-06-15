# lex-marketdata — instrument reference data types
#
# Instrument holds the static reference attributes for a tradeable symbol.
# Store access lives in refdata_store.lex (effects: [ref_data, sql]).
#
# Pure: no effects.

type AssetClass = Equity | FixedIncome | Commodity | FX | Derivative | ETF

type Instrument = { symbol :: Str, isin :: Str, cusip :: Str, lei :: Str, name :: Str, currency :: Str, exchange :: Str, asset_class :: AssetClass }

type RefDataError = InstrumentNotFound(Str) | RefDataConnectionError(Str) | InvalidSymbol(Str)

fn asset_class_name(ac :: AssetClass) -> Str {
  match ac {
    Equity => "Equity",
    FixedIncome => "FixedIncome",
    Commodity => "Commodity",
    FX => "FX",
    Derivative => "Derivative",
    ETF => "ETF",
  }
}

fn is_equity(inst :: Instrument) -> Bool {
  match inst.asset_class {
    Equity => true,
    _ => false,
  }
}

fn is_etf(inst :: Instrument) -> Bool {
  match inst.asset_class {
    ETF => true,
    _ => false,
  }
}

