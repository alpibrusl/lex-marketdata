# Tests for src/refdata_store.lex — in-memory SQLite.
#
# Effects: [ref_data, sql, fs_write]

import "std.list" as list

import "lex-orm/src/connection" as conn
import "lex-orm/src/error"      as dbe

import "../src/refdata"       as rd
import "../src/refdata_store" as rds

fn pass() -> Result[Unit, Str] { Ok(()) }
fn fail(why :: Str) -> Result[Unit, Str] { Err(why) }
fn assert_true(cond :: Bool, label :: Str) -> Result[Unit, Str] {
  if cond { pass() } else { fail(label) }
}

fn open_db() -> [ref_data, sql, fs_write] Result[conn.ConnDb, Str] {
  match conn.connect_sqlite(":memory:") {
    Err(err) => Err(dbe.message(err)),
    Ok(db)   => match rds.init(db) {
      Err(err) => Err(dbe.message(err)),
      Ok(_)    => Ok(db),
    },
  }
}

fn aapl_instrument() -> rd.Instrument {
  {
    symbol:      "AAPL",
    isin:        "US0378331005",
    cusip:       "037833100",
    lei:         "HWUPKR0MPOU8FGXBT394",
    name:        "Apple Inc.",
    currency:    "USD",
    exchange:    "NASDAQ",
    asset_class: rd.Equity,
  }
}

fn msft_instrument() -> rd.Instrument {
  {
    symbol:      "MSFT",
    isin:        "US5949181045",
    cusip:       "594918104",
    lei:         "INR2EJN1ERAN0W5ZP974",
    name:        "Microsoft Corporation",
    currency:    "USD",
    exchange:    "NASDAQ",
    asset_class: rd.Equity,
  }
}

# ---- Tests ----------------------------------------------------------

fn test_lookup_unknown_returns_not_found() -> [ref_data, sql, fs_write] Result[Unit, Str] {
  match open_db() {
    Err(msg) => fail(msg),
    Ok(db)   => match rds.lookup(db, "ZZZZ") {
      Err(dbe.DbNotFound) => pass(),
      Err(e)              => fail("expected DbNotFound, got: " + dbe.message(e)),
      Ok(_)               => fail("should not find ZZZZ"),
    },
  }
}

fn test_upsert_and_lookup() -> [ref_data, sql, fs_write] Result[Unit, Str] {
  match open_db() {
    Err(msg) => fail(msg),
    Ok(db)   => match rds.upsert_instrument(db, aapl_instrument()) {
      Err(e) => fail("upsert failed: " + dbe.message(e)),
      Ok(_)  => match rds.lookup(db, "AAPL") {
        Err(e)    => fail("lookup failed: " + dbe.message(e)),
        Ok(inst)  => match assert_true(inst.symbol == "AAPL", "symbol") {
          Err(e) => Err(e),
          Ok(_)  => match assert_true(inst.isin == "US0378331005", "isin") {
            Err(e) => Err(e),
            Ok(_)  => assert_true(inst.currency == "USD", "currency"),
          },
        },
      },
    },
  }
}

fn test_upsert_updates_existing() -> [ref_data, sql, fs_write] Result[Unit, Str] {
  match open_db() {
    Err(msg) => fail(msg),
    Ok(db)   => match rds.upsert_instrument(db, aapl_instrument()) {
      Err(e) => fail("first upsert: " + dbe.message(e)),
      Ok(_)  => {
        let updated := {
          symbol:      "AAPL",
          isin:        "US0378331005",
          cusip:       "037833100",
          lei:         "HWUPKR0MPOU8FGXBT394",
          name:        "Apple Inc. (Updated)",
          currency:    "USD",
          exchange:    "NASDAQ",
          asset_class: rd.Equity,
        }
        match rds.upsert_instrument(db, updated) {
          Err(e) => fail("second upsert: " + dbe.message(e)),
          Ok(_)  => match rds.lookup(db, "AAPL") {
            Err(e)   => fail("lookup: " + dbe.message(e)),
            Ok(inst) => assert_true(inst.name == "Apple Inc. (Updated)", "name updated"),
          },
        }
      },
    },
  }
}

fn test_two_instruments_isolated() -> [ref_data, sql, fs_write] Result[Unit, Str] {
  match open_db() {
    Err(msg) => fail(msg),
    Ok(db)   => match rds.upsert_instrument(db, aapl_instrument()) {
      Err(e) => fail("aapl upsert: " + dbe.message(e)),
      Ok(_)  => match rds.upsert_instrument(db, msft_instrument()) {
        Err(e) => fail("msft upsert: " + dbe.message(e)),
        Ok(_)  => match rds.lookup(db, "MSFT") {
          Err(e)   => fail("msft lookup: " + dbe.message(e)),
          Ok(inst) => assert_true(inst.exchange == "NASDAQ" and inst.symbol == "MSFT", "msft isolated"),
        },
      },
    },
  }
}

fn test_asset_class_round_trip() -> [ref_data, sql, fs_write] Result[Unit, Str] {
  match open_db() {
    Err(msg) => fail(msg),
    Ok(db)   => {
      let etf := {
        symbol:      "SPY",
        isin:        "US78462F1030",
        cusip:       "78462F103",
        lei:         "",
        name:        "SPDR S&P 500 ETF Trust",
        currency:    "USD",
        exchange:    "NYSE",
        asset_class: rd.ETF,
      }
      match rds.upsert_instrument(db, etf) {
        Err(e) => fail("upsert: " + dbe.message(e)),
        Ok(_)  => match rds.lookup(db, "SPY") {
          Err(e)   => fail("lookup: " + dbe.message(e)),
          Ok(inst) => match inst.asset_class {
            rd.ETF => pass(),
            _      => fail("expected ETF asset class"),
          },
        },
      }
    },
  }
}

fn test_remove() -> [ref_data, sql, fs_write] Result[Unit, Str] {
  match open_db() {
    Err(msg) => fail(msg),
    Ok(db)   => match rds.upsert_instrument(db, aapl_instrument()) {
      Err(e) => fail("upsert: " + dbe.message(e)),
      Ok(_)  => match rds.remove(db, "AAPL") {
        Err(e) => fail("remove: " + dbe.message(e)),
        Ok(_)  => match rds.lookup(db, "AAPL") {
          Err(dbe.DbNotFound) => pass(),
          Err(e)              => fail("expected DbNotFound after remove"),
          Ok(_)               => fail("should be gone after remove"),
        },
      },
    },
  }
}

# ---- Suite ----------------------------------------------------------

fn suite() -> [ref_data, sql, fs_write] List[Result[Unit, Str]] {
  [
    test_lookup_unknown_returns_not_found(),
    test_upsert_and_lookup(),
    test_upsert_updates_existing(),
    test_two_instruments_isolated(),
    test_asset_class_round_trip(),
    test_remove(),
  ]
}

fn run_all() -> [ref_data, sql, fs_write] Int {
  list.fold(suite(), 0, fn (acc :: Int, r :: Result[Unit, Str]) -> Int {
    match r { Ok(_) => acc, Err(_) => acc + 1 }
  })
}
