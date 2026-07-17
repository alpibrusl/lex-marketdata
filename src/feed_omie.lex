# lex-marketdata — OMIE day-ahead spot price feed (#8)
#
# The Iberian day-ahead market publishes hourly marginal prices as a daily
# semicolon file (marginalpdbc): a MARGINALPDBC; header, one row per hour
#   YYYY;MM;DD;HH;PRICE_PT;PRICE_ES;
# and an asterisk terminator. Prices are EUR/MWh, parsed as exact decimals
# (lex-money) — a spot curve is money, floats need not apply.
#
# fetch_day pulls one day; parse_marginalpdbc is pure and fixture-testable.
# Consumers: energy-flex tender pricing (lex-ev-fleet#122) and the voltrelay
# tariff DP (offline export).

import "std.str" as str

import "std.int" as int

import "std.list" as list

import "std.http" as http

import "std.bytes" as bytes

import "lex-money/src/decimal" as d

type HourlyPrice = { zone :: Str, date :: Str, hour :: Int, eur_mwh :: d.Decimal }

fn pad2(n :: Int) -> Str {
  if n < 10 {
    str.concat("0", int.to_str(n))
  } else {
    int.to_str(n)
  }
}

fn parse_int_str(s :: Str) -> Option[Int] {
  str.to_int(str.trim(s))
}

# One data row -> the two zone entries (PT first in the file, then ES).
fn parse_row(line :: Str) -> List[HourlyPrice] {
  let parts := str.split(line, ";")
  if list.len(parts) < 6 {
    []
  } else {
    let indexed := list.enumerate(parts)
    let at := fn (i :: Int) -> Str {
      match list.head(list.filter(indexed, fn (e :: (Int, Str)) -> Bool {
        match e {
          (idx, _) => idx == i,
        }
      })) {
        Some(e2) => match e2 {
          (_, v) => str.trim(v),
        },
        None => "",
      }
    }
    match parse_int_str(at(0)) {
      None => [],
      Some(y) => match parse_int_str(at(1)) {
        None => [],
        Some(mo) => match parse_int_str(at(2)) {
          None => [],
          Some(day) => match parse_int_str(at(3)) {
            None => [],
            Some(h) => {
              let date := str.join([int.to_str(y), "-", pad2(mo), "-", pad2(day)], "")
              let pt := d.parse(at(4))
              let es := d.parse(at(5))
              let pt_row := match pt {
                Some(p) => [{ zone: "PT", date: date, hour: h, eur_mwh: p }],
                None => [],
              }
              let es_row := match es {
                Some(p) => [{ zone: "ES", date: date, hour: h, eur_mwh: p }],
                None => [],
              }
              list.concat(pt_row, es_row)
            },
          },
        },
      },
    }
  }
}

# Pure parser: header required (this IS a marginalpdbc file or it isn't),
# malformed rows and the terminator are skipped.
fn parse_marginalpdbc(text :: Str) -> Result[List[HourlyPrice], Str] {
  let lines := str.split(text, "\n")
  let has_header := match list.head(lines) {
    Some(first) => str.starts_with(str.trim(first), "MARGINALPDBC"),
    None => false,
  }
  if not has_header {
    Err("not a MARGINALPDBC file")
  } else {
    Ok(list.fold(list.tail(lines), [], fn (acc :: List[HourlyPrice], line :: Str) -> List[HourlyPrice] {
      let t := str.trim(line)
      if str.is_empty(t) or str.starts_with(t, "*") {
        acc
      } else {
        list.concat(acc, parse_row(t))
      }
    }))
  }
}

fn default_base_url() -> Str {
  "https://www.omie.es"
}

# yyyymmdd like "20260716". The .1 suffix is the definitive daily file.
fn day_url(base_url :: Str, yyyymmdd :: Str) -> Str {
  str.join([base_url, "/es/file-download?parents=marginalpdbc&filename=marginalpdbc_", yyyymmdd, ".1"], "")
}

fn fetch_day(base_url :: Str, yyyymmdd :: Str) -> [net] Result[List[HourlyPrice], Str] {
  match http.get(day_url(base_url, yyyymmdd)) {
    Err(_) => Err("omie fetch failed"),
    Ok(res) => if res.status >= 400 {
      Err(str.concat("omie http ", int.to_str(res.status)))
    } else {
      match bytes.to_str(res.body) {
        Err(_) => Err("omie body not utf-8"),
        Ok(text) => parse_marginalpdbc(text),
      }
    },
  }
}

# The price for one zone+hour out of a parsed day; None when absent.
fn price_at(prices :: List[HourlyPrice], zone :: Str, hour :: Int) -> Option[d.Decimal] {
  match list.head(list.filter(prices, fn (p :: HourlyPrice) -> Bool {
    p.zone == zone and p.hour == hour
  })) {
    Some(p) => Some(p.eur_mwh),
    None => None,
  }
}
