#!/usr/bin/env python3

import csv
import sys
from pathlib import Path


def sql_literal(value):
    if value is None:
        return "null"
    text = str(value).strip()
    if text == "":
        return "null"
    escaped = text.replace("'", "''")
    return f"'{escaped}'"


def sql_numeric(value):
    if value is None:
        return "null"
    text = str(value).strip()
    if text == "":
        return "null"
    try:
        return str(round(float(text), 2))
    except Exception:
        return "null"


def sql_bool(value):
    raw = str(value or "").strip().lower()
    return "true" if raw in {"true", "1", "yes", "active"} else "false"


def build_note(row):
    parts = []
    external_code = (row.get("external_code") or "").strip()
    source_type = (row.get("source_type") or "").strip()
    source_section = (row.get("source_section") or "").strip()
    supplier_name = (row.get("supplier_name") or "").strip()

    if source_type:
        parts.append(f"Zdrojový typ: {source_type}.")
    if source_section:
        parts.append(f"Zdrojová sekce: {source_section}.")
    if supplier_name:
        parts.append(f"Poslední dodavatel: {supplier_name}.")
    if external_code and external_code != (row.get("sku") or "").strip():
        parts.append(f"Externí kód: {external_code}.")
    return " ".join(parts)


def build_sql(rows):
    lines = [
        "-- Generated from tmp/products-import-preview.csv",
        "-- Imports products as master data only, without stock balances.",
        "-- Safe to run repeatedly: upsert by sku.",
        "",
        "begin;",
        "",
    ]

    for row in rows:
        sku = (row.get("sku") or "").strip()
        name = (row.get("name") or "").strip()
        category = (row.get("product_category") or "").strip()
        usage_type = (row.get("usage_type") or "").strip()
        base_unit = (row.get("base_unit") or "").strip() or "ks"

        if not sku or not name or not category or not usage_type:
            continue

        note = build_note(row)
        insert = f"""insert into public.products (
  name,
  sku,
  ean,
  product_category,
  usage_type,
  base_unit,
  sale_price,
  active,
  note
)
values (
  {sql_literal(name)},
  {sql_literal(sku)},
  {sql_literal((row.get("ean") or "").strip())},
  {sql_literal(category)},
  {sql_literal(usage_type)},
  {sql_literal(base_unit)},
  {sql_numeric(row.get("sale_price"))},
  {sql_bool(row.get("status"))},
  {sql_literal(note)}
)
on conflict (sku) do update
set
  name = excluded.name,
  ean = excluded.ean,
  product_category = excluded.product_category,
  usage_type = excluded.usage_type,
  base_unit = excluded.base_unit,
  sale_price = excluded.sale_price,
  active = excluded.active,
  note = excluded.note,
  updated_at = now();"""
        lines.append(insert)
        lines.append("")

    lines.extend([
        "commit;",
        "",
    ])
    return "\n".join(lines)


def main() -> int:
    if len(sys.argv) != 3:
        print("Usage: generate_products_import_sql.py <input.csv> <output.sql>")
        return 1

    input_path = Path(sys.argv[1]).expanduser()
    output_path = Path(sys.argv[2]).expanduser()

    with input_path.open(newline="", encoding="utf-8") as handle:
        rows = list(csv.DictReader(handle))

    sql = build_sql(rows)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(sql, encoding="utf-8")
    print(f"Generated SQL: {output_path}")
    print(f"Rows: {len(rows)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
