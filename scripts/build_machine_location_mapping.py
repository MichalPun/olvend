#!/usr/bin/env python3

import csv
import re
import sys
from pathlib import Path


def normalize_source_name(value: str) -> str:
    normalized = (value or "").strip()
    normalized = normalized.replace("_POTRAVINY", "")
    normalized = normalized.replace(" POTRAVINY", "")
    normalized = normalized.replace("_KÁVA", "")
    normalized = normalized.replace(" KÁVA", "")
    normalized = normalized.replace("_KAVA", "")
    normalized = normalized.replace(" KAVA", "")
    normalized = re.sub(r"\s+", " ", normalized).strip(" -_")
    return normalized.casefold()


def extract_source_names(route_note: str) -> list[str]:
    lines = (route_note or "").splitlines()
    output = []
    capture = False
    for line in lines:
        if line.startswith("Zdrojové názvy:"):
            capture = True
            line = line.split(":", 1)[1].strip()
        elif capture and re.match(r"^[A-ZÁČĎÉĚÍŇÓŘŠŤÚŮÝŽa-z0-9].*:", line):
            break
        elif not capture:
            continue

        for part in line.split(" | "):
            part = part.strip()
            if part:
                output.append(part)
    return output


def load_location_map(path: Path) -> dict[str, dict[str, str]]:
    with path.open(newline="", encoding="utf-8") as handle:
        rows = list(csv.DictReader(handle))

    mapping: dict[str, dict[str, str]] = {}
    for row in rows:
        source_names = extract_source_names(row.get("route_note", ""))
        canonical = {
            "location_name": row.get("name", ""),
            "city": row.get("city", ""),
            "address": row.get("address", ""),
        }
        for source_name in source_names:
            mapping[normalize_source_name(source_name)] = canonical
    return mapping


def build_outputs(
    machines_path: Path,
    location_map: dict[str, dict[str, str]],
) -> tuple[list[dict[str, str]], list[dict[str, str]]]:
    with machines_path.open(newline="", encoding="utf-8") as handle:
        machines = list(csv.DictReader(handle))

    mapping_rows = []
    enriched_rows = []
    seen_sources = set()

    for machine in machines:
        source_name = (machine.get("source_location_name") or "").strip()
        normalized = normalize_source_name(source_name)
        match = location_map.get(normalized)
        needs_review = "false" if match or not source_name else "true"

        if source_name and source_name not in seen_sources:
            seen_sources.add(source_name)
            mapping_rows.append(
                {
                    "source_location_name": source_name,
                    "normalized_source_location_name": normalized,
                    "olvend_location_name": match["location_name"] if match else "",
                    "olvend_city": match["city"] if match else "",
                    "olvend_address": match["address"] if match else "",
                    "mapping_source": "historical_locations_import" if match else "unmatched",
                    "needs_manual_review": needs_review,
                }
            )

        enriched = dict(machine)
        enriched["normalized_source_location_name"] = normalized
        enriched["olvend_location_name"] = match["location_name"] if match else ""
        enriched["olvend_city"] = match["city"] if match else ""
        enriched["olvend_address"] = match["address"] if match else ""
        enriched["location_mapping_status"] = "matched" if match else "unmatched"
        enriched_rows.append(enriched)

    mapping_rows.sort(key=lambda row: (row["needs_manual_review"], row["source_location_name"]))
    return mapping_rows, enriched_rows


def write_csv(path: Path, rows: list[dict[str, str]]) -> None:
    if not rows:
        return
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=list(rows[0].keys()))
        writer.writeheader()
        writer.writerows(rows)


def main() -> int:
    if len(sys.argv) != 5:
        print(
            "Usage: build_machine_location_mapping.py <machines.csv> <locations.csv> "
            "<mapping-output.csv> <enriched-machines-output.csv>"
        )
        return 1

    machines_path = Path(sys.argv[1]).expanduser()
    locations_path = Path(sys.argv[2]).expanduser()
    mapping_output_path = Path(sys.argv[3]).expanduser()
    enriched_output_path = Path(sys.argv[4]).expanduser()

    location_map = load_location_map(locations_path)
    mapping_rows, enriched_rows = build_outputs(machines_path, location_map)
    write_csv(mapping_output_path, mapping_rows)
    write_csv(enriched_output_path, enriched_rows)

    matched = sum(1 for row in mapping_rows if row["needs_manual_review"] == "false")
    unmatched = len(mapping_rows) - matched
    print(f"Location mappings: {len(mapping_rows)}")
    print(f"Matched: {matched}")
    print(f"Needs review: {unmatched}")
    print(f"Mapping output: {mapping_output_path}")
    print(f"Enriched machines output: {enriched_output_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
