# lex-marketdata — Polygon.io previous-day close feed adapter
#
# Fetches the previous trading day's OHLCV from Polygon.io REST API
# and returns a Quote. The close price is used as `last`; a synthetic
# ±$0.01 spread gives bid/ask for callers that need a well-formed Quote.
#
# For real-time bid/ask, use the Polygon.io WebSocket feed.
#
# Effects: [net]

import "std.net"   as net
import "std.str"   as str
import "std.float" as float
import "std.int"   as int
import "std.list"  as list

import "lex-money/src/decimal" as d
import "lex-schema/json_value" as jv

import "./quote" as q

# Convert a float price to a 4-decimal-place Decimal.
# Multiplies by 10000, rounds to nearest int, then wraps with exponent -4.
fn price_to_decimal(f :: Float) -> d.Decimal {
  let scaled  := f * 10000.0
  let rounded := float.to_int(scaled + 0.5)
  d.decimal(rounded, -4)
}

# Synthetic spread helpers — add or subtract one cent from a price.
fn add_cent(p :: d.Decimal) -> d.Decimal {
  d.add(p, d.decimal(1, -2))
}

fn sub_cent(p :: d.Decimal) -> d.Decimal {
  d.sub(p, d.decimal(1, -2))
}

# Build the Polygon.io previous-day aggregates URL for a ticker.
fn polygon_prev_url(ticker :: Str, api_key :: Str) -> Str {
  "https://api.polygon.io/v2/aggs/ticker/" + ticker + "/prev?adjusted=true&apiKey=" + api_key
}

# Fetch the previous-day close for a single ticker from Polygon.io.
#
# On success returns Ok(Quote) where:
#   last = previous-day close price
#   bid  = last - $0.01  (synthetic)
#   ask  = last + $0.01  (synthetic)
fn get_quote(ticker :: Str, api_key :: Str) -> [net] Result[q.Quote, q.MarketDataError] {
  let url := polygon_prev_url(ticker, api_key)
  let resp := net.get(url, [])
  match resp {
    Err(msg) =>
      Err(q.ConnectionError(msg)),
    Ok(r) =>
      match jv.parse(r.body) {
        Err(_) =>
          Err(q.MdParseError("JSON parse failed for ticker: " + ticker)),
        Ok(json) =>
          # Extract the results array
          match jv.get_field(json, "results") {
            None =>
              Err(q.MdParseError("Missing 'results' field for ticker: " + ticker)),
            Some(results_json) =>
              match results_json {
                JList(items) =>
                  match list.head(items) {
                    None =>
                      Err(q.SymbolNotFound(ticker)),
                    Some(item) =>
                      # Extract close price from "c" field
                      match jv.get_field(item, "c") {
                        None =>
                          Err(q.MdParseError("Missing 'c' field for ticker: " + ticker)),
                        Some(c_json) =>
                          let close_float :=
                            match c_json {
                              JFloat(f) => Ok(f),
                              JInt(n)   => Ok(int.to_float(n)),
                              _            => Err(q.MdParseError("'c' is not numeric for ticker: " + ticker)),
                            }
                          match close_float {
                            Err(e) => Err(e),
                            Ok(cf) =>
                              # Extract timestamp from "t" field
                              let ts_str :=
                                match jv.get_field(item, "t") {
                                  None => "",
                                  Some(t_json) =>
                                    match t_json {
                                      JInt(n)   => int.to_str(n),
                                      JFloat(f) => float.to_str(f),
                                      _            => "",
                                    },
                                }
                              let last := price_to_decimal(cf)
                              let bid  := sub_cent(last)
                              let ask  := add_cent(last)
                              Ok({
                                symbol:    ticker,
                                bid:       bid,
                                ask:       ask,
                                last:      last,
                                timestamp: ts_str,
                              })
                          }
                      }
                  },
                _ =>
                  Err(q.MdParseError("'results' is not a list for ticker: " + ticker)),
              }
          }
      }
  }
}

# Fetch previous-day quotes for a list of tickers.
# Returns one Result per ticker in the same order.
fn get_quotes(tickers :: List[Str], api_key :: Str) -> [net] List[Result[q.Quote, q.MarketDataError]] {
  list.map(tickers, fn(ticker :: Str) -> [net] Result[q.Quote, q.MarketDataError] {
    get_quote(ticker, api_key)
  })
}
