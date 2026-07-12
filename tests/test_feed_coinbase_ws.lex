# Tests for src/feed_coinbase_ws.lex — pure parsing logic only (no live
# connection). The fixture below is a real message captured from
# wss://ws-feed.exchange.coinbase.com during manual verification.
#
# All tests are pure (no effects).

import "std.list" as list

import "lex-schema/json_value" as jv

import "../src/feed_coinbase_ws" as fc

fn pass() -> Result[Unit, Str] {
  Ok(())
}

fn fail(why :: Str) -> Result[Unit, Str] {
  Err(why)
}

fn assert_true(cond :: Bool, label :: Str) -> Result[Unit, Str] {
  if cond {
    pass()
  } else {
    fail(label)
  }
}

fn real_ticker_json() -> Str {
  "{\"type\":\"ticker\",\"sequence\":132496480346,\"product_id\":\"BTC-USD\",\"price\":\"63934.5\",\"open_24h\":\"64107.68\",\"volume_24h\":\"2971.99241535\",\"low_24h\":\"63588.2\",\"high_24h\":\"64458.7\",\"volume_30d\":\"214124.18825716\",\"best_bid\":\"63934.00\",\"best_bid_size\":\"0.20953286\",\"best_ask\":\"63934.51\",\"best_ask_size\":\"0.18205\",\"time\":\"2026-07-12T05:30:00.123456Z\"}"
}

# ---- parse_decimal_str ------------------------------------------------
fn test_parse_decimal_str_basic() -> Result[Unit, Str] {
  match fc.parse_decimal_str("63929.77") {
    None => fail("should parse"),
    Some(d) => assert_true(d.coefficient == 6392977 and d.exponent == -2, "coefficient/exponent"),
  }
}

fn test_parse_decimal_str_integer_only() -> Result[Unit, Str] {
  match fc.parse_decimal_str("63934") {
    None => fail("should parse"),
    Some(d) => assert_true(d.coefficient == 63934 and d.exponent == 0, "integer only"),
  }
}

fn test_parse_decimal_str_leading_zero_frac() -> Result[Unit, Str] {
  match fc.parse_decimal_str("1.05") {
    None => fail("should parse"),
    Some(d) => assert_true(d.coefficient == 105 and d.exponent == -2, "leading zero fraction"),
  }
}

fn test_parse_decimal_str_negative() -> Result[Unit, Str] {
  match fc.parse_decimal_str("-0.5") {
    None => fail("should parse"),
    Some(d) => assert_true(d.coefficient == 0 - 5 and d.exponent == -1, "negative"),
  }
}

fn test_parse_decimal_str_garbage() -> Result[Unit, Str] {
  match fc.parse_decimal_str("not-a-number") {
    None => pass(),
    Some(_) => fail("garbage should not parse"),
  }
}

# ---- quote_from_ticker (real captured message shape) ------------------
fn test_quote_from_real_ticker_message() -> Result[Unit, Str] {
  match jv.parse(real_ticker_json()) {
    Err(_) => fail("fixture should parse as JSON"),
    Ok(obj) => match fc.quote_from_ticker(obj) {
      None => fail("should extract a Quote from a real ticker message"),
      Some(quote) => {
        let sym_ok := quote.symbol == "BTC-USD"
        let last_ok := quote.last.coefficient == 6393450 and quote.last.exponent == -2
        let bid_ok := quote.bid.coefficient == 6393400 and quote.bid.exponent == -2
        let ask_ok := quote.ask.coefficient == 6393451 and quote.ask.exponent == -2
        assert_true(sym_ok and last_ok and bid_ok and ask_ok, "quote fields")
      },
    },
  }
}

fn test_quote_from_subscriptions_ack_is_none() -> Result[Unit, Str] {
  match jv.parse("{\"type\":\"subscriptions\",\"channels\":[]}") {
    Err(_) => fail("fixture should parse as JSON"),
    Ok(obj) => match fc.quote_from_ticker(obj) {
      None => pass(),
      Some(_) => fail("a subscriptions ack is not a Quote"),
    },
  }
}

# ---- subscribe_msg ------------------------------------------------------
fn test_subscribe_msg_shape() -> Result[Unit, Str] {
  let msg := fc.subscribe_msg(["BTC-USD", "ETH-USD"])
  let has_type := msg == "{\"type\":\"subscribe\",\"product_ids\":[\"BTC-USD\",\"ETH-USD\"],\"channels\":[\"ticker\"]}"
  assert_true(has_type, "subscribe message shape")
}

# ---- Suite ----------------------------------------------------------
fn suite() -> List[Result[Unit, Str]] {
  [test_parse_decimal_str_basic(), test_parse_decimal_str_integer_only(), test_parse_decimal_str_leading_zero_frac(), test_parse_decimal_str_negative(), test_parse_decimal_str_garbage(), test_quote_from_real_ticker_message(), test_quote_from_subscriptions_ack_is_none(), test_subscribe_msg_shape()]
}

fn run_all() -> Int {
  list.fold(suite(), 0, fn (acc :: Int, r :: Result[Unit, Str]) -> Int {
    match r {
      Ok(_) => acc,
      Err(_) => acc + 1,
    }
  })
}
