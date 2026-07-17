# tests for src/feed_omie.lex — the pure marginalpdbc parser (#8).

import "std.str" as str

import "std.list" as list

import "lex-money/src/decimal" as d

import "../src/feed_omie" as omie

fn assert_true(cond :: Bool, label :: Str) -> Result[Unit, Str] {
  if cond {
    Ok(())
  } else {
    Err(label)
  }
}

fn fixture() -> Str {
  "MARGINALPDBC;\n2026;07;16;1;173.58;170.10;\n2026;07;16;2;169.04;169.04;\ngarbage line\n2026;07;16;3;;168.15;\n*\n"
}

# Expects 5 rows: h1 (PT+ES) + h2 (PT+ES) + h3 (ES only — the empty PT field is
# skipped, not parsed as zero).
fn test_parses_zones_and_decimals() -> Result[Unit, Str] {
  match omie.parse_marginalpdbc(fixture()) {
    Err(e) => Err(str.concat("should parse: ", e)),
    Ok(prices) => {
      let n := list.len(prices)
      let es1 := omie.price_at(prices, "ES", 1)
      let pt1 := omie.price_at(prices, "PT", 1)
      let es3 := omie.price_at(prices, "ES", 3)
      let pt3 := omie.price_at(prices, "PT", 3)
      let es1_ok := match es1 {
        Some(p) => d.to_str(p) == "170.10" or d.to_str(p) == "170.1",
        None => false,
      }
      let pt1_ok := match pt1 {
        Some(p) => d.to_str(p) == "173.58",
        None => false,
      }
      let pt3_absent := match pt3 {
        None => true,
        Some(_) => false,
      }
      let es3_ok := match es3 {
        Some(p) => d.to_str(p) == "168.15",
        None => false,
      }
      assert_true(n == 5 and es1_ok and pt1_ok and pt3_absent and es3_ok, str.concat("parsed shape wrong, n=", str.concat(if es1_ok {
        "e"
      } else {
        "E"
      }, if pt3_absent {
        "a"
      } else {
        "A"
      })))
    },
  }
}

fn test_rejects_non_omie_file() -> Result[Unit, Str] {
  match omie.parse_marginalpdbc("<html>redirect page</html>") {
    Err(_) => Ok(()),
    Ok(_) => Err("html page must not parse"),
  }
}

fn run_all() -> [io, sql, fs_read, fs_write, time, crypto, random, net, concurrent, llm, proc] Unit {
  let results := [test_parses_zones_and_decimals(), test_rejects_non_omie_file()]
  let failures := list.fold(results, [], fn (acc :: List[Str], r :: Result[Unit, Str]) -> List[Str] {
    match r {
      Ok(_) => acc,
      Err(m) => list.concat(acc, [m]),
    }
  })
  if list.is_empty(failures) {
    ()
  } else {
    let __boom := 1 / 0
    ()
  }
}

