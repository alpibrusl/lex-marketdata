# lex-marketdata — SQL-backed instrument reference data store
#
# Schema (DDL created by init):
#   instruments (
#     symbol      TEXT NOT NULL PRIMARY KEY,
#     isin        TEXT NOT NULL DEFAULT '',
#     cusip       TEXT NOT NULL DEFAULT '',
#     lei         TEXT NOT NULL DEFAULT '',
#     name        TEXT NOT NULL DEFAULT '',
#     currency    TEXT NOT NULL DEFAULT '',
#     exchange    TEXT NOT NULL DEFAULT '',
#     asset_class TEXT NOT NULL DEFAULT 'Equity'
#   )
#
# lookup returns Err(InstrumentNotFound) when the row is absent.
# upsert_instrument performs an INSERT … ON CONFLICT DO UPDATE so it
# can serve both initial seed and live updates.
#
# Effects: [ref_data, sql]

import "std.sql"  as sql
import "std.list" as list

import "lex-orm/src/connection" as conn
import "lex-orm/src/query"      as q
import "lex-orm/src/error"      as dbe

import "./refdata" as rd

fn init(db :: conn.ConnDb) -> [ref_data, sql] Result[Unit, dbe.DbErr] {
  let ddl := "CREATE TABLE IF NOT EXISTS instruments (symbol TEXT NOT NULL PRIMARY KEY, isin TEXT NOT NULL DEFAULT '', cusip TEXT NOT NULL DEFAULT '', lei TEXT NOT NULL DEFAULT '', name TEXT NOT NULL DEFAULT '', currency TEXT NOT NULL DEFAULT '', exchange TEXT NOT NULL DEFAULT '', asset_class TEXT NOT NULL DEFAULT 'Equity')"
  match sql.exec(db.handle, ddl, []) {
    Err(e) => Err(dbe.sql_error(match e.code { None => "", Some(c) => c }, e.message)),
    Ok(_)  => Ok(()),
  }
}

fn lookup(db :: conn.ConnDb, symbol :: Str) -> [ref_data, sql] Result[rd.Instrument, dbe.DbErr] {
  let sq := q.for_dialect(
    { sql: "SELECT symbol, isin, cusip, lei, name, currency, exchange, asset_class FROM instruments WHERE symbol = ?",
      params: [PStr(symbol)] },
    db.dialect
  )
  let raw :: Result[List[{ symbol :: Str, isin :: Str, cusip :: Str, lei :: Str, name :: Str, currency :: Str, exchange :: Str, asset_class :: Str }], SqlError] :=
    sql.query(db.handle, sq.sql, sq.params)
  match raw {
    Err(e) => Err(dbe.sql_error(match e.code { None => "", Some(c) => c }, e.message)),
    Ok(rows) => match list.head(rows) {
      None      => Err(dbe.not_found()),
      Some(row) => Ok(decode_row(row)),
    },
  }
}

fn upsert_instrument(db :: conn.ConnDb, inst :: rd.Instrument) -> [ref_data, sql] Result[Unit, dbe.DbErr] {
  let ac_str := rd.asset_class_name(inst.asset_class)
  let sq := q.for_dialect(
    { sql: "INSERT INTO instruments (symbol, isin, cusip, lei, name, currency, exchange, asset_class) VALUES (?, ?, ?, ?, ?, ?, ?, ?) ON CONFLICT (symbol) DO UPDATE SET isin = EXCLUDED.isin, cusip = EXCLUDED.cusip, lei = EXCLUDED.lei, name = EXCLUDED.name, currency = EXCLUDED.currency, exchange = EXCLUDED.exchange, asset_class = EXCLUDED.asset_class",
      params: [
        PStr(inst.symbol),
        PStr(inst.isin),
        PStr(inst.cusip),
        PStr(inst.lei),
        PStr(inst.name),
        PStr(inst.currency),
        PStr(inst.exchange),
        PStr(ac_str),
      ] },
    db.dialect
  )
  match sql.exec(db.handle, sq.sql, sq.params) {
    Err(e) => Err(dbe.sql_error(match e.code { None => "", Some(c) => c }, e.message)),
    Ok(_)  => Ok(()),
  }
}

fn remove(db :: conn.ConnDb, symbol :: Str) -> [ref_data, sql] Result[Unit, dbe.DbErr] {
  let sq := q.for_dialect(
    { sql: "DELETE FROM instruments WHERE symbol = ?",
      params: [PStr(symbol)] },
    db.dialect
  )
  match sql.exec(db.handle, sq.sql, sq.params) {
    Err(e) => Err(dbe.sql_error(match e.code { None => "", Some(c) => c }, e.message)),
    Ok(_)  => Ok(()),
  }
}

# ---- Internal -------------------------------------------------------

fn decode_asset_class(s :: Str) -> rd.AssetClass {
  if s == "FixedIncome" { rd.FixedIncome }
  else {
    if s == "Commodity" { rd.Commodity }
    else {
      if s == "FX" { rd.FX }
      else {
        if s == "Derivative" { rd.Derivative }
        else {
          if s == "ETF" { rd.ETF }
          else { rd.Equity }
        }
      }
    }
  }
}

fn decode_row(
  row :: { symbol :: Str, isin :: Str, cusip :: Str, lei :: Str, name :: Str, currency :: Str, exchange :: Str, asset_class :: Str }
) -> rd.Instrument {
  {
    symbol:      row.symbol,
    isin:        row.isin,
    cusip:       row.cusip,
    lei:         row.lei,
    name:        row.name,
    currency:    row.currency,
    exchange:    row.exchange,
    asset_class: decode_asset_class(row.asset_class),
  }
}
