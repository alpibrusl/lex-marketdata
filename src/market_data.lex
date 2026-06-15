# lex-marketdata — market data interface types
#
# This module defines the shared types used across market-data consumers.
# Actual live-feed access is injected at the server level (e.g. lex-oms)
# via a platform adapter that holds the [market_data] capability.
#
# For tests and simulation, use mock.lex which provides the same
# get_quote / get_reference_price signatures without any runtime effects.
#
# Pure: no effects.

import "std.list" as list

import "./quote" as q

# Describes a market-data subscription intent.
# The runtime resolves on_quote to a registered callback by name.
type Subscription = { symbol :: Str, on_quote :: Str }

fn subscription(symbol :: Str, handler :: Str) -> Subscription {
  { symbol: symbol, on_quote: handler }
}

# SubscriptionList is the configuration value passed to server startup
# so the runtime knows which symbols to subscribe on.
type SubscriptionList = List[Subscription]

fn subscribe_all(symbols :: List[Str], handler :: Str) -> SubscriptionList {
  list.map(symbols, fn (sym :: Str) -> Subscription {
    subscription(sym, handler)
  })
}

