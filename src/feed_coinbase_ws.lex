# lex-marketdata — Coinbase Exchange real-time ticker feed adapter
#
# Connects to Coinbase's public `ticker` WebSocket channel — unauthenticated
# market data, no API key needed — and invokes a caller-supplied callback
# with a Quote for every tick received. Confirmed live end-to-end against
# the real feed (wss://ws-feed.exchange.coinbase.com) via a throwaway
# connectivity spike before this file was written: one connection can
# subscribe to multiple product_ids at once, ticker frames come back
# tagged by product_id, and price/best_bid/best_ask all arrive as JSON
# STRINGS (e.g. "63929.77"), not numbers.
#
# Uses raw net.dial_ws, not lex-web's ws.dial wrapper — deliberately, to
# avoid pulling a whole HTTP-server-routing package into what is a
# data-client library; lex-web itself documents ws.dial as a convenience
# layer over net.dial_ws, not the only supported way to call it.
#
# `net.dial_ws` blocks for the lifetime of the connection (it loops
# internally, invoking `on_message` per inbound frame) — callers that want
# this running in the background should spawn `listen` under std.conc.
#
# `on_tick`'s effect row is deliberately concrete (`[sql]`), not generic —
# this toolchain's user-level functions don't support row-polymorphic
# effects (only builtins like dial_ws itself do, via the Rust type
# checker). `[sql]` matches the one real consumer this adapter has today
# (caching the latest tick into a table); broaden this if a consumer with
# a genuinely different effect need shows up.
#
# Effects: [net, sql]

import "std.net" as net

import "std.str" as str

import "std.list" as list

import "lex-money/src/decimal" as d

import "lex-schema/json_value" as jv

import "./quote" as q

fn coinbase_url() -> Str {
  "wss://ws-feed.exchange.coinbase.com"
}

fn subscribe_msg(product_ids :: List[Str]) -> Str {
  let quoted := list.map(product_ids, fn (p :: Str) -> Str {
    str.join(["\"", p, "\""], "")
  })
  str.join(["{\"type\":\"subscribe\",\"product_ids\":[", str.join(quoted, ","), "],\"channels\":[\"ticker\"]}"], "")
}

# Coinbase sends plain decimal strings like "63929.77" — parsed directly
# to avoid a float round-trip. Same shape as lex-positions/src/
# position.lex's parse_price; duplicated locally rather than taking a new
# dependency on lex-positions (a position-tracking library, the wrong
# layer for a market-data package to depend on) just for a string parser.
fn parse_decimal_str(s :: Str) -> Option[d.Decimal] {
  let is_neg := str.len(s) > 0 and str.slice(s, 0, 1) == "-"
  let unsigned := if is_neg {
    str.slice(s, 1, str.len(s))
  } else {
    s
  }
  let parts := str.split(unsigned, ".")
  match list.head(parts) {
    None => None,
    Some(int_part) => match list.head(list.tail(parts)) {
      None => match str.to_int(int_part) {
        None => None,
        Some(n) => Some(if is_neg {
          d.negate(d.from_int(n))
        } else {
          d.from_int(n)
        }),
      },
      Some(frac_part) => match str.to_int(int_part) {
        None => None,
        Some(int_n) => match str.to_int(frac_part) {
          None => None,
          Some(frac_n) => {
            let exp := 0 - str.len(frac_part)
            let coeff := int_n * d.pow10(str.len(frac_part)) + frac_n
            Some(if is_neg {
              d.negate(d.decimal(coeff, exp))
            } else {
              d.decimal(coeff, exp)
            })
          },
        },
      },
    },
  }
}

fn json_str_field(obj :: jv.Json, key :: Str) -> Option[Str] {
  match jv.get_field(obj, key) {
    Some(JStr(s)) => Some(s),
    _ => None,
  }
}

fn quote_from_ticker(obj :: jv.Json) -> Option[q.Quote] {
  match json_str_field(obj, "type") {
    Some("ticker") => match json_str_field(obj, "product_id") {
      None => None,
      Some(pid) => match json_str_field(obj, "price") {
        None => None,
        Some(price_s) => match parse_decimal_str(price_s) {
          None => None,
          Some(last) => {
            let bid := match json_str_field(obj, "best_bid") {
              Some(s) => match parse_decimal_str(s) {
                Some(v) => v,
                None => last,
              },
              None => last,
            }
            let ask := match json_str_field(obj, "best_ask") {
              Some(s) => match parse_decimal_str(s) {
                Some(v) => v,
                None => last,
              },
              None => last,
            }
            let ts := match json_str_field(obj, "time") {
              Some(t) => t,
              None => "",
            }
            Some({ symbol: pid, bid: bid, ask: ask, last: last, timestamp: ts })
          },
        },
      },
    },
    _ => None,
  }
}

# Blocks for the lifetime of the connection. `on_tick` is invoked once per
# parsed ticker frame; any frame that isn't a recognized "ticker" message
# (the initial "subscriptions" ack, heartbeats, etc.) is silently skipped.
fn listen(product_ids :: List[Str], on_tick :: (q.Quote) -> [sql] Unit) -> [net, sql] Result[Unit, Str] {
  net.dial_ws(
    coinbase_url(),
    "",
    fn () -> [sql] WsAction {
      WsSend(subscribe_msg(product_ids))
    },
    fn (msg :: WsMessage) -> [sql] WsAction {
      match msg {
        WsText(body) => {
          let _ := match jv.parse(body) {
            Ok(obj) => match quote_from_ticker(obj) {
              Some(quote) => on_tick(quote),
              None => (),
            },
            Err(_) => (),
          }
          WsNoOp
        },
        WsBinary(_) => WsNoOp,
        WsPing => WsNoOp,
        WsClose => WsNoOp,
      }
    },
  )
}
