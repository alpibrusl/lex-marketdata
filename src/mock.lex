# lex-marketdata — pure canned-data mock
#
# Returns deterministic Quote values without any [market_data] effect.
# Use in tests and simulation where a live feed is unavailable.
#
# Pure: no effects.

import "lex-money/src/decimal" as d

import "./quote" as q

fn make_price(c :: Int, e :: Int) -> d.Decimal {
  d.decimal(c, e)
}

fn aapl() -> q.Quote {
  {
    symbol:    "AAPL",
    bid:       make_price(17490, -2),   # 174.90
    ask:       make_price(17492, -2),   # 174.92
    last:      make_price(17491, -2),   # 174.91
    timestamp: "20260528-09:30:00.000",
  }
}

fn msft() -> q.Quote {
  {
    symbol:    "MSFT",
    bid:       make_price(41850, -2),   # 418.50
    ask:       make_price(41852, -2),   # 418.52
    last:      make_price(41851, -2),   # 418.51
    timestamp: "20260528-09:30:00.000",
  }
}

fn tsla() -> q.Quote {
  {
    symbol:    "TSLA",
    bid:       make_price(17240, -2),   # 172.40
    ask:       make_price(17243, -2),   # 172.43
    last:      make_price(17241, -2),   # 172.41
    timestamp: "20260528-09:30:00.000",
  }
}

fn get_quote(symbol :: Str) -> Result[q.Quote, q.MarketDataError] {
  if symbol == "AAPL" { Ok(aapl()) }
  else {
    if symbol == "MSFT" { Ok(msft()) }
    else {
      if symbol == "TSLA" { Ok(tsla()) }
      else { Err(q.SymbolNotFound(symbol)) }
    }
  }
}

fn get_reference_price(symbol :: Str) -> Result[d.Decimal, q.MarketDataError] {
  match get_quote(symbol) {
    Err(e)    => Err(e),
    Ok(quote) => Ok(quote.last),
  }
}
