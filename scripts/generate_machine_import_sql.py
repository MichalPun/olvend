#!/usr/bin/env python3

import csv
import sys
from pathlib import Path


def sql_literal(value):
    if value is None:
      return "null"
    text = str(value)
    if text == "":
      return "null"
    escaped = text.replace("'", "''")
    return f"'{escaped}'"


def sql_bool(value):
    return "true" if str(value).strip().lower() == "true" else "false"


def location_subquery(row):
    name = (row.get("olvend_location_name") or "").strip()
    city = (row.get("olvend_city") or "").strip()
    address = (row.get("olvend_address") or "").strip()
    if not name:
        return "null"

    conditions = [f"name = {sql_literal(name)}"]
    if city:
        conditions.append(f"coalesce(city, '') = {sql_literal(city)}")
    if address:
        conditions.append(f"coalesce(address, '') = {sql_literal(address)}")

    return f"(select id from public.locations where {' and '.join(conditions)} order by id limit 1)"


def build_note(row):
    parts = []
    base_note = (row.get("note") or "").strip()
    telemetry_id = (row.get("telemetry_external_id") or "").strip()
    source_location = (row.get("source_location_name") or "").strip()
    if base_note:
        parts.append(base_note)
    if telemetry_id:
        parts.append(f"Telemetry ID: {telemetry_id}.")
    if source_location:
        parts.append(f"Zdrojová lokalita: {source_location}.")
    return " ".join(parts)


def build_sql(rows):
    lines = [
        "-- Generated from imports/machines-import-ready.csv",
        "-- Safe to run repeatedly: upsert by qr_token",
        "",
    ]

    for row in rows:
        source_code = (row.get("source_code") or "").strip()
        if not source_code:
            continue

        qr_token = f"vendsoft-{source_code}"
        insert = f"""insert into public.machines (
  location_id,
  name,
  machine_type,
  brand,
  model,
  serial_number,
  evidence_number,
  status,
  active,
  note,
  qr_token
)
values (
  {location_subquery(row)},
  {sql_literal((row.get("name") or "").strip())},
  {sql_literal((row.get("machine_type") or "").strip() or "Neuvedeno")},
  {sql_literal((row.get("brand") or "").strip())},
  {sql_literal((row.get("model") or "").strip())},
  {sql_literal((row.get("serial_number") or "").strip())},
  {sql_literal((row.get("evidence_number") or source_code).strip())},
  {sql_literal((row.get("status") or "").strip() or "ok")},
  {sql_bool(row.get("active", "true"))},
  {sql_literal(build_note(row))},
  {sql_literal(qr_token)}
)
on conflict (qr_token) do update
set
  location_id = excluded.location_id,
  name = excluded.name,
  machine_type = excluded.machine_type,
  brand = excluded.brand,
  model = excluded.model,
  serial_number = excluded.serial_number,
  evidence_number = excluded.evidence_number,
  status = excluded.status,
  active = excluded.active,
  note = excluded.note;"""
        lines.append(insert)
        lines.append("")

    return "\n".join(lines)


def main() -> int:
    if len(sys.argv) != 3:
        print("Usage: generate_machine_import_sql.py <input.csv> <output.sql>")
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
