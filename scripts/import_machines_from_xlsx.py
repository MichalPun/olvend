#!/usr/bin/env python3

import csv
import sys
import zipfile
import xml.etree.ElementTree as ET
from pathlib import Path

NS = {"a": "http://schemas.openxmlformats.org/spreadsheetml/2006/main"}


def load_shared_strings(archive: zipfile.ZipFile) -> list[str]:
    if "xl/sharedStrings.xml" not in archive.namelist():
      return []
    root = ET.fromstring(archive.read("xl/sharedStrings.xml"))
    output = []
    for item in root.findall("a:si", NS):
        texts = [node.text or "" for node in item.iterfind(".//a:t", NS)]
        output.append("".join(texts))
    return output


def parse_rows(path: Path) -> list[dict[str, str]]:
    with zipfile.ZipFile(path) as archive:
        shared_strings = load_shared_strings(archive)
        sheet = ET.fromstring(archive.read("xl/worksheets/sheet1.xml"))
        rows = sheet.find("a:sheetData", NS)
        parsed = []
        header_map = {}
        for row in rows:
            values = {}
            for cell in row.findall("a:c", NS):
                ref = cell.attrib.get("r", "")
                column = "".join(ch for ch in ref if ch.isalpha())
                cell_type = cell.attrib.get("t")
                value_node = cell.find("a:v", NS)
                value = ""
                if value_node is not None:
                    raw = value_node.text or ""
                    if cell_type == "s":
                        index = int(raw)
                        value = shared_strings[index] if index < len(shared_strings) else raw
                    else:
                        value = raw
                values[column] = value
            if not header_map:
                header_map = {column: values.get(column, "").strip() for column in sorted(values)}
                continue
            record = {}
            for column, header in header_map.items():
                if not header:
                    continue
                record[header] = values.get(column, "").strip()
            parsed.append(record)
        return parsed


def normalize_status(name: str) -> tuple[bool, str]:
    upper = name.upper()
    if "PRODÁNO" in upper or "PRODANO" in upper or "ODPRODÁNO" in upper or "ODPRODANO" in upper:
        return False, "removed"
    return True, "ok"


def convert_rows(rows: list[dict[str, str]]) -> list[dict[str, str]]:
    converted = []
    for row in rows:
        name = row.get("Název", "")
        if not name:
            continue
        active, status = normalize_status(name)
        location_name = row.get("Lokalita", "")
        converted.append(
            {
                "source_code": row.get("Kód", ""),
                "evidence_number": row.get("Kód", ""),
                "name": name,
                "machine_type": row.get("Typ", ""),
                "brand": row.get("Model", ""),
                "model": "",
                "slot_count": row.get("Sloupce", ""),
                "source_location_name": location_name,
                "fill_level_percent": row.get("% naplnění", ""),
                "last_fill_at": row.get("Čas posledního naplnění", ""),
                "telemetry_external_id": row.get("ID telemetrie", ""),
                "last_visit_date": row.get("Poslední návštěva", ""),
                "last_visit_at": row.get("Čas poslední návštěvy", ""),
                "last_dex_at": row.get("Poslední DEX", ""),
                "last_vend_at": row.get("Čas posledního výdeje", ""),
                "cash_sales": row.get("Hotovostní prodej", ""),
                "card_sales": row.get("Bezhotovostní prodej", ""),
                "serial_number": row.get("Sériové číslo", ""),
                "revision_valid_to": row.get("Platnost revize do", ""),
                "acquisition_price": row.get("Pořizovací cena", ""),
                "total_sales_count": row.get("Vybráno celkem", ""),
                "product_expiry_hint": row.get("Trvanlivost", ""),
                "days_since_visit": row.get("Dny od návštěvy", ""),
                "active": "true" if active else "false",
                "status": status,
                "note": f"Import z VendSoft exportu; původní kód {row.get('Kód', '-')}; lokalita '{location_name or '-'}'.",
            }
        )
    return converted


def write_csv(path: Path, rows: list[dict[str, str]]) -> None:
    if not rows:
        return
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=list(rows[0].keys()))
        writer.writeheader()
        writer.writerows(rows)


def main() -> int:
    if len(sys.argv) < 3:
        print("Usage: import_machines_from_xlsx.py <input.xlsx> <output.csv>")
        return 1
    input_path = Path(sys.argv[1]).expanduser()
    output_path = Path(sys.argv[2]).expanduser()
    rows = parse_rows(input_path)
    converted = convert_rows(rows)
    write_csv(output_path, converted)
    print(f"Imported rows: {len(converted)}")
    print(f"Output: {output_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
