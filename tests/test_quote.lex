# Tests for src/quote.lex and src/mock.lex — pure logic.
#
# All tests are pure (no effects).

import "std.list" as list

import "lex-money/src/decimal" as d

import "../src/quote" as q
import "../src/mock"  as mock

fn pass() -> Result[Unit, Str] { Ok(()) }
fn fail(why :: Str) -> Result[Unit, Str] { Err(why) }
fn assert_true(cond :: Bool, label :: Str) -> Result[Unit, Str] {
  if cond { pass() } else { fail(label) }
}

# ---- mock.get_quote -------------------------------------------------

fn test_mock_aapl_returns_quote() -> Result[Unit, Str] {
  match mock.get_quote("AAPL") {
    Err(_)    => fail("AAPL should be known"),
    Ok(quote) => assert_true(quote.symbol == "AAPL", "symbol"),
  }
}

fn test_mock_msft_returns_quote() -> Result[Unit, Str] {
  match mock.get_quote("MSFT") {
    Err(_)    => fail("MSFT should be known"),
    Ok(quote) => assert_true(quote.symbol == "MSFT", "symbol"),
  }
}

fn test_mock_unknown_symbol_is_err() -> Result[Unit, Str] {
  match mock.get_quote("ZZZZ") {
    Err(q.SymbolNotFound(sym)) => assert_true(sym == "ZZZZ", "sym"),
    Err(_)                     => fail("expected SymbolNotFound"),
    Ok(_)                      => fail("ZZZZ should not be found"),
  }
}

# ---- mock.get_reference_price ---------------------------------------

fn test_mock_reference_price_aapl() -> Result[Unit, Str] {
  match mock.get_reference_price("AAPL") {
    Err(_) => fail("AAPL reference price should resolve"),
    Ok(p)  => assert_true(p.coefficient == 17491 and p.exponent == -2, "aapl last price"),
  }
}

fn test_mock_reference_price_unknown() -> Result[Unit, Str] {
  match mock.get_reference_price("NOPE") {
    Err(q.SymbolNotFound(_)) => pass(),
    Err(_)                   => fail("expected SymbolNotFound"),
    Ok(_)                    => fail("should not resolve"),
  }
}

# ---- quote helpers --------------------------------------------------

fn test_mid_price() -> Result[Unit, Str] {
  let quote := mock.aapl()
  let m := q.mid(quote)
  # bid=17490, ask=17492, both exponent -2; sum=34982; mid coeff = 34982/2 = 17491
  assert_true(m.coefficient == 17491 and m.exponent == -2, "mid")
}

fn test_spread() -> Result[Unit, Str] {
  let quote := mock.aapl()
  let s := q.spread(quote)
  # ask 17492 - bid 17490 = 2, exponent -2
  assert_true(s.coefficient == 2 and s.exponent == -2, "spread")
}

# ---- Suite ----------------------------------------------------------

fn suite() -> List[Result[Unit, Str]] {
  [
    test_mock_aapl_returns_quote(),
    test_mock_msft_returns_quote(),
    test_mock_unknown_symbol_is_err(),
    test_mock_reference_price_aapl(),
    test_mock_reference_price_unknown(),
    test_mid_price(),
    test_spread(),
  ]
}

fn run_all() -> Int {
  list.fold(suite(), 0, fn (acc :: Int, r :: Result[Unit, Str]) -> Int {
    match r { Ok(_) => acc, Err(_) => acc + 1 }
  })
}
