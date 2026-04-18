#!/usr/bin/env python3
from __future__ import annotations

import csv
import re
import sys
import zipfile
import xml.etree.ElementTree as ET
from collections import Counter, defaultdict
from pathlib import Path


NS = {
    "a": "http://schemas.openxmlformats.org/spreadsheetml/2006/main",
    "r": "http://schemas.openxmlformats.org/officeDocument/2006/relationships",
}

CATEGORY_SUFFIXES = (
    "KÁVA",
    "POTRAVINY",
    "COLA",
)


def normalize(value: str | None) -> str:
    return re.sub(r"\s+", " ", str(value or "").strip().lower())


def title_or_none(value: str | None) -> str | None:
    text = str(value or "").strip()
    return text or None


def sql(value: str | bool | None) -> str:
    if value is None:
        return "null"
    if isinstance(value, bool):
        return "true" if value else "false"
    escaped = str(value).replace("'", "''")
    return f"'{escaped}'"


def read_xlsx_rows(path: Path) -> list[dict[str, str]]:
    with zipfile.ZipFile(path) as archive:
        workbook = ET.fromstring(archive.read("xl/workbook.xml"))
        rels = ET.fromstring(archive.read("xl/_rels/workbook.xml.rels"))
        rel_map = {rel.attrib["Id"]: rel.attrib["Target"] for rel in rels}

        shared_strings: list[str] = []
        if "xl/sharedStrings.xml" in archive.namelist():
            shared_root = ET.fromstring(archive.read("xl/sharedStrings.xml"))
            for si in shared_root.findall("a:si", NS):
                shared_strings.append("".join(t.text or "" for t in si.iterfind(".//a:t", NS)))

        def cell_value(cell: ET.Element) -> str:
            cell_type = cell.attrib.get("t")
            value_node = cell.find("a:v", NS)
            value = value_node.text if value_node is not None else ""
            if cell_type == "s" and value.isdigit():
                return shared_strings[int(value)]
            inline = cell.find("a:is", NS)
            if inline is not None:
                return "".join(t.text or "" for t in inline.iterfind(".//a:t", NS))
            return value

        sheet = workbook.find("a:sheets", NS)[0]
        rel_id = sheet.attrib["{http://schemas.openxmlformats.org/officeDocument/2006/relationships}id"]
        target = rel_map[rel_id]
        if not target.startswith("xl/"):
            target = f"xl/{target}"

        sheet_root = ET.fromstring(archive.read(target))
        rows = sheet_root.findall(".//a:sheetData/a:row", NS)

        def colref(cellref: str) -> str:
            return re.match(r"[A-Z]+", cellref).group(0)

        header: dict[str, str] = {}
        for cell in rows[0].findall("a:c", NS):
            header[colref(cell.attrib["r"])] = cell_value(cell)

        parsed_rows: list[dict[str, str]] = []
        for row in rows[1:]:
            item: dict[str, str] = {}
            for cell in row.findall("a:c", NS):
                item[header[colref(cell.attrib["r"])]] = cell_value(cell)
            parsed_rows.append(item)
        return parsed_rows


def cleaned_location_name(raw_name: str) -> str:
    text = str(raw_name or "").strip()
    if "_" in text:
        text = text.split("_", 1)[1]
    text = re.sub(r"\s*-\s*", " ", text)
    text = re.sub(
        rf"\b(?:{'|'.join(re.escape(item) for item in CATEGORY_SUFFIXES)})\b",
        "",
        text,
        flags=re.IGNORECASE,
    )
    text = re.sub(r"\s+", " ", text).strip(" -_,")
    return text or str(raw_name or "").strip()


def common_prefix_name(names: list[str]) -> str:
    token_lists = [re.split(r"\s+", name) for name in names if name]
    if not token_lists:
        return ""

    prefix: list[str] = []
    for token_group in zip(*token_lists):
        first = normalize(token_group[0])
        if first and all(normalize(token) == first for token in token_group[1:]):
            prefix.append(token_group[0])
        else:
            break

    if len(prefix) >= 2:
        return " ".join(prefix).strip()

    counts = Counter(names)
    ranked = sorted(counts.items(), key=lambda item: (-item[1], len(item[0]), item[0]))
    return ranked[0][0].strip()


def names_related(left: str, right: str) -> bool:
    left_norm = normalize(left)
    right_norm = normalize(right)
    if not left_norm or not right_norm:
        return False
    if left_norm == right_norm:
        return True
    if "sidlo" in left_norm or "sidlo" in right_norm:
        return False
    if left_norm in right_norm or right_norm in left_norm:
        return True

    left_tokens = left_norm.split()
    right_tokens = right_norm.split()
    common = []
    for left_token, right_token in zip(left_tokens, right_tokens):
        if left_token == right_token:
            common.append(left_token)
        else:
            break
    return len(common) >= 2


def cluster_rows(rows: list[dict[str, str]]) -> list[list[dict[str, str]]]:
    clusters: list[list[dict[str, str]]] = []
    for row in rows:
        clean_name = cleaned_location_name(row.get("Název", ""))
        placed = False
        for cluster in clusters:
            if any(names_related(clean_name, cleaned_location_name(existing.get("Název", ""))) for existing in cluster):
                cluster.append(row)
                placed = True
                break
        if not placed:
            clusters.append([row])
    return clusters


def best_value(values: list[str]) -> str | None:
    cleaned = [str(value).strip() for value in values if str(value or "").strip()]
    if not cleaned:
        return None
    counts = Counter(cleaned)
    ranked = sorted(counts.items(), key=lambda item: (-item[1], len(item[0]), item[0]))
    return ranked[0][0]


def build_route_note(rows: list[dict[str, str]]) -> str:
    source_names = sorted({str(row.get("Název", "")).strip() for row in rows if str(row.get("Název", "")).strip()})
    source_codes = sorted({str(row.get("Kód", "")).strip() for row in rows if str(row.get("Kód", "")).strip()})
    routes = sorted({str(row.get("Trasy", "")).strip() for row in rows if str(row.get("Trasy", "")).strip()})
    operators = sorted({str(row.get("Operátor", "")).strip() for row in rows if str(row.get("Operátor", "")).strip()})
    service_days = sorted({str(row.get("Servisní dny", "")).strip() for row in rows if str(row.get("Servisní dny", "")).strip()})
    sectors = sorted({str(row.get("SEKTOR", "")).strip() for row in rows if str(row.get("SEKTOR", "")).strip()})
    service_categories = sorted({str(row.get("Kategorie servis", "")).strip() for row in rows if str(row.get("Kategorie servis", "")).strip()})

    total_machines = 0
    for row in rows:
        raw = str(row.get("Automaty", "")).strip()
        if raw.isdigit():
            total_machines += int(raw)

    lines = []
    if source_codes:
        lines.append(f"Zdrojové kódy: {', '.join(source_codes)}")
    if source_names:
        lines.append(f"Zdrojové názvy: {' | '.join(source_names)}")
    if routes:
        lines.append(f"Trasy: {' | '.join(routes)}")
    if operators:
        lines.append(f"Operátor: {' | '.join(operators)}")
    if service_days:
        lines.append(f"Servisní dny: {' | '.join(service_days)}")
    if service_categories:
        lines.append(f"Kategorie servisu: {' | '.join(service_categories)}")
    if sectors:
        lines.append(f"Sektor: {' | '.join(sectors)}")
    if total_machines:
        lines.append(f"Počet automatů ve zdroji: {total_machines}")
    return "\n".join(lines) or None


def consolidate_locations(rows: list[dict[str, str]]) -> list[dict[str, str | bool | None]]:
    grouped: dict[tuple[str, str], list[dict[str, str]]] = defaultdict(list)
    for row in rows:
        key = (normalize(row.get("Adresa", "")), normalize(row.get("Město", "")))
        grouped[key].append(row)

    consolidated: list[dict[str, str | bool | None]] = []
    for (_, _), address_rows in grouped.items():
        for cluster in cluster_rows(address_rows):
            clean_names = [cleaned_location_name(row.get("Název", "")) for row in cluster]
            name = common_prefix_name(clean_names)
            city = best_value([row.get("Město", "") for row in cluster])
            address = best_value([row.get("Adresa", "") for row in cluster])
            customer_name = best_value(clean_names) or name
            contact_person = best_value([row.get("Kontaktní jméno", "") for row in cluster])
            contact_phone = best_value([row.get("Kontaktní telefon", "") for row in cluster])
            service_window_values = sorted({str(row.get("Servisní dny", "")).strip() for row in cluster if str(row.get("Servisní dny", "")).strip()})
            service_window = " | ".join(service_window_values) if service_window_values else None
            active = any(normalize(row.get("Stav", "")) == "active" for row in cluster)
            note = build_route_note(cluster)

            consolidated.append(
                {
                    "name": name,
                    "city": title_or_none(city),
                    "address": title_or_none(address),
                    "customer_name": title_or_none(customer_name),
                    "contact_person": title_or_none(contact_person),
                    "contact_phone": title_or_none(contact_phone),
                    "service_window": title_or_none(service_window),
                    "route_note": note,
                    "vendsoft_location_id": None,
                    "active": active,
                }
            )

    consolidated.sort(key=lambda item: (normalize(str(item.get("city") or "")), normalize(str(item.get("name") or ""))))
    return consolidated


def write_csv(path: Path, rows: list[dict[str, str | bool | None]]) -> None:
    fieldnames = [
        "name",
        "city",
        "address",
        "customer_name",
        "contact_person",
        "contact_phone",
        "service_window",
        "route_note",
        "vendsoft_location_id",
        "active",
    ]
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)


def write_sql(path: Path, rows: list[dict[str, str | bool | None]]) -> None:
    columns = [
        "name",
        "city",
        "address",
        "customer_name",
        "contact_person",
        "contact_phone",
        "service_window",
        "route_note",
        "vendsoft_location_id",
        "active",
    ]
    lines = [
        "-- Import lokalit vygenerovaný z Excelu Lokality-2026-04-18.xlsx",
        "-- Sloučeno primárně podle adresy + města, s ochranou proti sloučení nesouvisejících názvů na stejné adrese.",
        "-- Pokud chceš tabulku před importem vyčistit, odkomentuj další řádek.",
        "-- truncate table public.locations restart identity;",
        "",
    ]
    for row in rows:
        values = ", ".join(sql(row.get(column)) for column in columns)
        lines.append(
            f"insert into public.locations ({', '.join(columns)}) values ({values});"
        )
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def main() -> int:
    source = Path(sys.argv[1]) if len(sys.argv) > 1 else Path("/Users/michalpuncochar/Downloads/Lokality-2026-04-18.xlsx")
    out_dir = Path(sys.argv[2]) if len(sys.argv) > 2 else Path("imports")
    out_dir.mkdir(parents=True, exist_ok=True)

    rows = read_xlsx_rows(source)
    consolidated = consolidate_locations(rows)

    csv_path = out_dir / "locations-import.csv"
    sql_path = out_dir / "locations-import.sql"
    write_csv(csv_path, consolidated)
    write_sql(sql_path, consolidated)

    print(f"Zdrojových řádků: {len(rows)}")
    print(f"Výsledných lokalit: {len(consolidated)}")
    print(f"CSV: {csv_path}")
    print(f"SQL: {sql_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
