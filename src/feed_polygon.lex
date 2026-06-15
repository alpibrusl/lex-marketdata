# lex-marketdata — Polygon.io previous-day close feed adapter
#
# Fetches the previous trading day's OHLCV from Polygon.io REST API
# and returns a Quote. The close price is used as `last`; a synthetic
# ±$0.01 spread gives bid/ask for callers that need a well-formed Quote.
#
# For real-time bid/ask, use the Polygon.io WebSocket feed.
#
# Effects: [net]

import "std.net" as net

import "std.float" as float

import "std.int" as int

import "std.list" as list

import "lex-money/src/decimal" as d

import "lex-schema/json_value" as jv

import "./quote" as q

fn price_to_decimal(f :: Float) -> d.Decimal {
  let rounded := float.to_int(f * 10000.0 + 0.5)
  d.decimal(rounded, -4)
}

fn add_cent(p :: d.Decimal) -> d.Decimal {
  d.add(p, d.decimal(1, -2))
}

fn sub_cent(p :: d.Decimal) -> d.Decimal {
  d.sub(p, d.decimal(1, -2))
}

fn polygon_prev_url(ticker :: Str, api_key :: Str) -> Str {
  "https://api.polygon.io/v2/aggs/ticker/" + ticker + "/prev?adjusted=true&apiKey=" + api_key
}

fn extract_timestamp(item :: jv.Json) -> Str {
  match jv.get_field(item, "t") {
    None => "",
    Some(JInt(n)) => int.to_str(n),
    Some(JFloat(f)) => float.to_str(f),
    Some(_) => "",
  }
}

fn extract_close(item :: jv.Json, ticker :: Str) -> Result[Float, q.MarketDataError] {
  match jv.get_field(item, "c") {
    None => Err(MdParseError("missing 'c' field for " + ticker)),
    Some(JFloat(f)) => Ok(f),
    Some(JInt(n)) => Ok(int.to_float(n)),
    Some(_) => Err(MdParseError("'c' is not numeric for " + ticker)),
  }
}

fn build_quote(ticker :: Str, item :: jv.Json) -> Result[q.Quote, q.MarketDataError] {
  match extract_close(item, ticker) {
    Err(e) => Err(e),
    Ok(cf) => {
      let last := price_to_decimal(cf)
      Ok({ symbol: ticker, bid: sub_cent(last), ask: add_cent(last), last: last, timestamp: extract_timestamp(item) })
    },
  }
}

fn parse_response(ticker :: Str, body :: Str) -> Result[q.Quote, q.MarketDataError] {
  match jv.parse(body) {
    Err(_) => Err(MdParseError("JSON parse failed for " + ticker)),
    Ok(json) => match jv.get_field(json, "results") {
      None => Err(MdParseError("missing 'results' for " + ticker)),
      Some(JList(items)) => match list.head(items) {
        None => Err(SymbolNotFound(ticker)),
        Some(item) => build_quote(ticker, item),
      },
      Some(_) => Err(MdParseError("'results' is not a list for " + ticker)),
    },
  }
}

# Fetch previous-day close for a ticker from Polygon.io.
# Returns Ok(Quote) with last=close, bid=close-$0.01, ask=close+$0.01.
fn get_quote(ticker :: Str, api_key :: Str) -> [net] Result[q.Quote, q.MarketDataError] {
  match net.get(polygon_prev_url(ticker, api_key)) {
    Err(msg) => Err(ConnectionError(msg)),
    Ok(body) => parse_response(ticker, body),
  }
}

# Fetch quotes for a list of tickers in order.
fn get_quotes(tickers :: List[Str], api_key :: Str) -> [net] List[Result[q.Quote, q.MarketDataError]] {
  match list.head(tickers) {
    None => [],
    Some(ticker) => list.concat([get_quote(ticker, api_key)], get_quotes(list.tail(tickers), api_key)),
  }
}

