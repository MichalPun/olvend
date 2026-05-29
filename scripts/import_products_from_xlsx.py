#!/usr/bin/env python3
import csv
import json
import re
import sys
import zipfile
import xml.etree.ElementTree as ET
from pathlib import Path

NS = {
    'main': 'http://schemas.openxmlformats.org/spreadsheetml/2006/main'
}
CELL_REF_RE = re.compile(r'([A-Z]+)(\d+)')


CATEGORY_MAP = {
    'Teplé nápoje': ('beverage_ready', 'direct_sale', 'ks'),
    'Cukrovinky': ('snack_ready', 'direct_sale', 'ks'),
    'Vody': ('beverage_ready', 'direct_sale', 'ks'),
    'Bageta': ('food_ready', 'direct_sale', 'ks'),
    'Ingredient': ('ingredient', 'recipe_consumption', 'g'),
    'Zrnková káva': ('ingredient', 'recipe_consumption', 'g')
}


def col_idx(ref: str) -> int:
    match = CELL_REF_RE.match(ref)
    if not match:
      return 0
    col = match.group(1)
    value = 0
    for char in col:
        value = value * 26 + (ord(char) - 64)
    return value - 1


def load_xlsx_rows(path: Path):
    with zipfile.ZipFile(path) as archive:
        shared_strings = []
        if 'xl/sharedStrings.xml' in archive.namelist():
            root = ET.fromstring(archive.read('xl/sharedStrings.xml'))
            for item in root.findall('main:si', NS):
                shared_strings.append(''.join(text.text or '' for text in item.iter('{http://schemas.openxmlformats.org/spreadsheetml/2006/main}t')))

        workbook = ET.fromstring(archive.read('xl/workbook.xml'))
        relationships = ET.fromstring(archive.read('xl/_rels/workbook.xml.rels'))
        rel_map = {rel.attrib['Id']: rel.attrib['Target'] for rel in relationships}
        first_sheet = workbook.find('main:sheets', NS)[0]
        xml_path = 'xl/' + rel_map[first_sheet.attrib['{http://schemas.openxmlformats.org/officeDocument/2006/relationships}id']].lstrip('/')
        root = ET.fromstring(archive.read(xml_path))

        rows = []
        for row in root.findall('.//main:sheetData/main:row', NS):
            current = []
            for cell in row.findall('main:c', NS):
                idx = col_idx(cell.attrib['r'])
                while len(current) < idx:
                    current.append('')
                cell_type = cell.attrib.get('t')
                value = ''
                raw_value = cell.find('main:v', NS)
                if cell_type == 's' and raw_value is not None:
                    value = shared_strings[int(raw_value.text)]
                elif cell_type == 'inlineStr':
                    inline = cell.find('main:is', NS)
                    value = ''.join(text.text or '' for text in inline.iter('{http://schemas.openxmlformats.org/spreadsheetml/2006/main}t')) if inline is not None else ''
                elif raw_value is not None:
                    value = raw_value.text or ''
                current.append(value)
            if any(str(item).strip() for item in current):
                rows.append(current)
        return rows


def number(value):
    try:
        return float(str(value).replace(',', '.').replace('\xa0', '').strip())
    except Exception:
        return None


def normalize_code(value):
    raw = str(value or '').strip()
    return raw or None


def normalize_barcode(value):
    raw = str(value or '').strip()
    if not raw:
        return None
    return raw


def map_category(source_value):
    source = str(source_value or '').strip()
    return CATEGORY_MAP.get(source, ('consumable', 'internal_consumption', 'ks'))


def build_rows(rows):
    header = rows[0]
    data = [row + [''] * (len(header) - len(row)) for row in rows[1:]]
    index = {name: pos for pos, name in enumerate(header)}

    def get(row, key):
        if key not in index:
            return ''
        pos = index[key]
        return row[pos] if pos < len(row) else ''

    output = []
    for row in data:
        code = normalize_code(get(row, 'Kód'))
        name = str(get(row, 'Název') or '').strip()
        if not code or not name:
            continue
        product_category, usage_type, base_unit = map_category(get(row, 'Typ'))
        output.append({
            'external_code': code,
            'name': name,
            'sku': code,
            'ean': normalize_barcode(get(row, 'Čárový kód')),
            'source_type': str(get(row, 'Typ') or '').strip() or None,
            'source_section': str(get(row, 'SEKCE') or '').strip() or None,
            'product_category': product_category,
            'usage_type': usage_type,
            'base_unit': base_unit,
            'sale_price': number(get(row, 'Prodejní cena základní')),
            'warehouse_qty': number(get(row, 'Ve skladu')),
            'vehicle_qty': number(get(row, 'V\xa0nákladních vozech')),
            'machine_qty': number(get(row, 'V\xa0automatech')),
            'total_qty': number(get(row, 'Celkové zásoby')),
            'supplier_name': str(get(row, 'Poslední dodavatel') or '').strip() or None,
            'status': str(get(row, 'Stav') or '').strip() or None
        })
    return output


def write_csv(rows, output_path: Path):
    fieldnames = [
        'external_code',
        'name',
        'sku',
        'ean',
        'source_type',
        'source_section',
        'product_category',
        'usage_type',
        'base_unit',
        'sale_price',
        'warehouse_qty',
        'vehicle_qty',
        'machine_qty',
        'total_qty',
        'supplier_name',
        'status'
    ]
    with output_path.open('w', newline='', encoding='utf-8') as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)


def main():
    if len(sys.argv) < 2:
        print('Usage: python3 scripts/import_products_from_xlsx.py /path/to/file.xlsx [output.csv]')
        sys.exit(1)

    source = Path(sys.argv[1]).expanduser()
    target = Path(sys.argv[2]).expanduser() if len(sys.argv) > 2 else Path('tmp/products-import-preview.csv')
    target.parent.mkdir(parents=True, exist_ok=True)

    rows = load_xlsx_rows(source)
    mapped = build_rows(rows)
    write_csv(mapped, target)

    summary = {
        'rows': len(mapped),
        'categories': {},
        'missing_ean': sum(1 for row in mapped if not row['ean']),
        'negative_machine_qty': [row['name'] for row in mapped if (row['machine_qty'] or 0) < 0][:20],
        'output': str(target)
    }
    for row in mapped:
        summary['categories'][row['source_type'] or 'Bez typu'] = summary['categories'].get(row['source_type'] or 'Bez typu', 0) + 1

    print(json.dumps(summary, ensure_ascii=False, indent=2))


if __name__ == '__main__':
    main()
