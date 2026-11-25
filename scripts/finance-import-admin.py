#!/usr/bin/env python3
"""Generate idempotent SQL calls for finance imports administered from the CLI.

The script only reads source exports and writes SQL to stdout. It intentionally
does not parse or forward Money S3 pre-accounting (MD/D) fields.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
import xml.etree.ElementTree as ET
import zipfile
from datetime import datetime
from decimal import Decimal
from pathlib import Path


def decimal(value: str | None) -> float:
    try:
        return float(Decimal((value or "0").strip().replace(" ", "").replace(",", ".")))
    except Exception:
        return 0.0


def text(node: ET.Element, tag: str) -> str | None:
    value = node.findtext(tag)
    return value.strip() if value and value.strip() else None


def money_rows(path: Path) -> tuple[list[dict], str | None, str]:
    raw = path.read_bytes()
    root = ET.fromstring(raw.decode("utf-8-sig"))
    rows = []
    for index, node in enumerate(root.iter("Zavazek"), start=1):
        total = decimal(text(node, "Celkem"))
        actual = decimal(text(node, "UhZbyva"))
        orderable = decimal(text(node, "PUZbyva"))
        rows.append(
            {
                "internal_number": text(node, "Doklad") or f"ZAVAZEK-{index}",
                "series": text(node, "DRada"),
                "series_number": int(text(node, "DCislo") or 0) or None,
                "description": text(node, "Popis") or "Bez popisu",
                "accounting_date": text(node, "DatUcPr"),
                "issue_date": text(node, "DatVyst"),
                "due_date": text(node, "DatSpl"),
                "taxable_date": text(node, "DatPln"),
                "received_date": text(node, "Doruceno"),
                "currency": "CZK",
                "total_amount": total,
                "actual_remaining_amount": actual,
                "orderable_remaining_amount": orderable,
                "ordered_amount": max(0, round(actual - orderable, 2)),
                "money_payment_date": text(node, "UhDatum"),
                "money_payment_document": text(node, "UhDokl"),
            }
        )
    return rows, root.attrib.get("ExpDate"), hashlib.sha256(raw).hexdigest()


def gpc_date(value: str) -> str | None:
    value = value.strip()
    if not re.fullmatch(r"\d{6}", value) or value == "000000":
        return None
    return datetime.strptime(value, "%d%m%y").date().isoformat()


def gpc_rows(path: Path) -> tuple[list[dict], str, int]:
    import_sha = hashlib.sha256(path.read_bytes()).hexdigest()
    rows: list[dict] = []
    if path.suffix.lower() == ".gpc":
        sources = [(path.name, path.read_bytes())]
    else:
        with zipfile.ZipFile(path) as archive:
            sources = [
                (name, archive.read(name))
                for name in sorted(archive.namelist())
                if name.lower().endswith(".gpc")
            ]
    for name, raw in sources:
        source_sha = hashlib.sha256(raw).hexdigest()
        lines = raw.decode("cp1250").splitlines()
        header = next((line for line in lines if line.startswith("074")), None)
        if not header:
            continue
        account_id = header[3:19].lstrip("0") or "0"
        statement_number = header[105:108].strip()
        currency_match = re.search(r"_(CZK|EUR)_", name, re.I)
        currency = currency_match.group(1).upper() if currency_match else "CZK"
        current: dict | None = None
        sequence = 0
        for line in lines:
            if line.startswith("075"):
                if current:
                    rows.append(current)
                sequence += 1
                code = line[60:61]
                amount = Decimal(line[48:60] or "0") / 100
                if code in {"1", "4"}:
                    amount = -amount
                counter_account = line[19:35].lstrip("0") or None
                bank_code = line[73:77].strip() or None
                variable_symbol = line[61:71].strip().lstrip("0") or None
                name_value = line[97:117].strip() or None
                booked_on = gpc_date(line[122:128]) or gpc_date(header[108:114])
                value_on = gpc_date(line[91:97])
                fingerprint = f"{account_id}|{name}|{sequence}|{line}".encode("utf-8")
                current = {
                    "account_id": account_id,
                    "external_id": hashlib.sha256(fingerprint).hexdigest(),
                    "booked_on": booked_on,
                    "value_on": value_on,
                    "amount": float(amount),
                    "currency": currency,
                    "counterparty_name": name_value,
                    "counterparty_account": counter_account,
                    "counterparty_bank_code": bank_code,
                    "variable_symbol": variable_symbol,
                    "message": None,
                    "statement_number": statement_number,
                    "booking_code": code,
                    "source_file_name": name,
                    "source_file_sha256": source_sha,
                    "source_sequence": sequence,
                    "import_sha256": import_sha,
                }
            elif current and line[:3] in {"078", "079"}:
                addition = line[3:].strip()
                if addition:
                    current["message"] = " ".join(filter(None, [current.get("message"), addition]))
        if current:
            rows.append(current)
    return rows, import_sha, len(sources)


def sql_text(value: str) -> str:
    return "'" + value.replace("'", "''") + "'"


def emit_calls(function: str, rows: list[dict], chunk_size: int, trailing_args, final_args, post_calls=None) -> None:
    print("begin;")
    print("select set_config('request.jwt.claim.role','service_role',true);")
    chunks = [rows[i : i + chunk_size] for i in range(0, len(rows), chunk_size)]
    for index, chunk in enumerate(chunks):
        payload = json.dumps(chunk, ensure_ascii=False, separators=(",", ":"))
        args = [f"$payload${payload}$payload$::jsonb", *trailing_args]
        args.extend(final_args(index == len(chunks) - 1))
        print(f"select public.{function}({','.join(args)});")
    for call in post_calls or []:
        print(call)
    print("commit;")


def main() -> None:
    parser = argparse.ArgumentParser()
    subparsers = parser.add_subparsers(dest="command", required=True)
    liabilities = subparsers.add_parser("liabilities-sql")
    liabilities.add_argument("xml", type=Path)
    bank = subparsers.add_parser("bank-sql")
    bank.add_argument("source", type=Path, help="Soubor .gpc nebo ZIP obsahující výpisy .gpc")
    args = parser.parse_args()

    if args.command == "liabilities-sql":
        rows, exported_at, sha = money_rows(args.xml)
        emit_calls(
            "finance_import_money_liabilities_v1",
            rows,
            75,
            [sql_text(args.xml.name), sql_text(sha), sql_text(exported_at or "") + "::date", str(len(rows))],
            lambda final: ["true" if final else "false"],
        )
        return

    rows, sha, statements = gpc_rows(args.source)
    emit_calls(
        "finance_import_gpc_transactions_v1",
        rows,
        125,
        [sql_text(sha), sql_text(args.source.name), str(statements), str(len(rows))],
        lambda final: ["true" if final else "false"],
        [f"select public.finance_reconcile_bank_import_v2({sql_text(sha)});"],
    )


if __name__ == "__main__":
    main()
