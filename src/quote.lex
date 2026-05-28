# lex-marketdata — market quote types
#
# Quote holds the best bid/ask and last trade price for a symbol.
# MarketDataError covers all retrieval failure modes.
#
# Pure: no effects.

import "lex-money/src/decimal" as d

type Quote = {
  symbol    :: Str,
  bid       :: d.Decimal,
  ask       :: d.Decimal,
  last      :: d.Decimal,
  timestamp :: Str,          # UTC, format "YYYYMMDD-HH:MM:SS.mmm"
}

type MarketDataError =
    SymbolNotFound(Str)
  | StaleData(Str, Str)     # (symbol, last_timestamp)
  | ConnectionError(Str)
  | ParseError(Str)

fn mid(q :: Quote) -> d.Decimal {
  let sum := d.add(q.bid, q.ask)
  { coefficient: sum.coefficient / 2, exponent: sum.exponent }
}

fn spread(q :: Quote) -> d.Decimal {
  d.sub(q.ask, q.bid)
}
