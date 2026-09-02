from pathlib import Path

from reportlab.lib import colors
from reportlab.lib.enums import TA_RIGHT
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle
from reportlab.lib.units import mm
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.platypus import KeepTogether, Paragraph, SimpleDocTemplate, Spacer, Table, TableStyle


ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "output" / "pdf" / "OLMIKA_objednavka_SOCO_2026-09-02.pdf"
FONT_DIR = ROOT / "assets" / "fonts"

ROWS = [
    ("Bongo kokos banán v mléčné polevě 40g", "0343-3401575", "SOCO-BONGO-BANAN-40", 1, 24, 6.62),
    ("Bongo kokos máta v tmavé polevě 40g", "0343-3401576", "SOCO-BONGO-MATA-40", 1, 24, 6.62),
    ("Bongo kokos originál v mléčné polevě 40g", "0343-3401585", "SOCO-BONGO-ORIGINAL-40", 1, 24, 6.62),
    ("Brigit kokosová tyčinka v tmavé polevě 90g", "0343-3401511", "SOCO-BRIGIT-90", 2, 20, 8.47),
    ("Coconut Extasy tyčinka s arašídovým máslem 45g", "0343-3401616", "SOCO-EXTASY-COCONUT-45", 2, 30, 8.93),
    ("Peanut Extasy tyčinka s arašídovým máslem 45g", "0343-3401609", "SOCO-EXTASY-PEANUT-45", 2, 30, 8.93),
    ("Proteinový suk s čokoládovou příchutí 45g", "", "SOCO-PROTEIN-COKOLADA-45", 1, 30, 7.51),
    ("Proteinový suk s vanilkovou příchutí 45g", "0343-3401435", "SOCO-PROTEIN-VANILKA-45", 2, 30, 7.51),
    ("RawBar with apple and cinnamon 40g", "0343-3401455", "SOCO-RAWBAR-APPLE", 2, 25, 8.90),
    ("RawBar with cranberries and almonds 40g", "0343-3401430", "SOCO-RAWBAR-CRANBERRY", 1, 25, 8.90),
    ("RawBar with peanuts 40g", "0343-3401418", "SOCO-RAWBAR-PEANUTS", 2, 25, 8.90),
]


def money(value: float) -> str:
    return f"{value:,.2f} Kč".replace(",", "X").replace(".", ",").replace("X", " ")


def build() -> None:
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    pdfmetrics.registerFont(TTFont("AptosNarrow", FONT_DIR / "Aptos-Narrow.ttf"))
    pdfmetrics.registerFont(TTFont("AptosNarrow-Bold", FONT_DIR / "Aptos-Narrow-Bold.ttf"))

    navy = colors.HexColor("#141E2B")
    red = colors.HexColor("#E1131F")
    muted = colors.HexColor("#667085")
    border = colors.HexColor("#DDE2E9")
    pale = colors.HexColor("#F7F9FC")

    doc = SimpleDocTemplate(
        str(OUTPUT), pagesize=A4, leftMargin=14 * mm, rightMargin=14 * mm,
        topMargin=12 * mm, bottomMargin=12 * mm,
        title="Objednávka SOCO – OLMIKA", author="OLMIKA s.r.o.",
    )
    normal = ParagraphStyle("normal", fontName="AptosNarrow", fontSize=8.3, leading=10.2, textColor=navy)
    small = ParagraphStyle("small", parent=normal, fontSize=7.2, leading=8.5, textColor=muted)
    bold = ParagraphStyle("bold", parent=normal, fontName="AptosNarrow-Bold")
    table_head = ParagraphStyle("table-head", parent=bold, textColor=colors.white)
    right = ParagraphStyle("right", parent=normal, alignment=TA_RIGHT)
    right_bold = ParagraphStyle("right-bold", parent=bold, alignment=TA_RIGHT)

    story = []
    header = Table([
        [Paragraph("<font size='22'><b>OBJEDNÁVKA ZBOŽÍ</b></font><br/><font size='9'>Návrh SOCO-20260902 · vystaveno 2. 9. 2026</font>", ParagraphStyle("hdr", parent=normal, textColor=colors.white, leading=16))]
    ], colWidths=[182 * mm], rowHeights=[27 * mm])
    header.setStyle(TableStyle([
        ("BACKGROUND", (0, 0), (-1, -1), navy), ("LEFTPADDING", (0, 0), (-1, -1), 10 * mm),
        ("VALIGN", (0, 0), (-1, -1), "MIDDLE"), ("LINEBEFORE", (0, 0), (0, -1), 4, red),
    ]))
    story += [header, Spacer(1, 5 * mm)]

    parties = Table([
        [Paragraph("<b>ODBĚRATEL</b>", bold), Paragraph("<b>DODAVATEL</b>", bold)],
        [Paragraph("<b>OLMIKA s.r.o.</b><br/>Lidická 700/19, 602 00 Brno<br/>IČO 04579968 · DIČ CZ04579968<br/>puncochar.m@olmika.cz · +420 774 954 766", normal),
         Paragraph("<b>SOCO CZ s.r.o.</b><br/>V Lipkách 645, 154 00 Praha 5<br/>IČO 28778511 · DIČ CZ28778511<br/>info@celita.cz · +420 465 539 167", normal)],
    ], colWidths=[91 * mm, 91 * mm])
    parties.setStyle(TableStyle([
        ("VALIGN", (0, 0), (-1, -1), "TOP"), ("BOTTOMPADDING", (0, 0), (-1, 0), 2 * mm),
        ("LINEBELOW", (0, -1), (-1, -1), .5, border), ("BOTTOMPADDING", (0, -1), (-1, -1), 4 * mm),
    ]))
    story += [parties, Spacer(1, 3 * mm)]

    delivery = Table([[Paragraph("<b>DODÁNÍ</b>", bold), Paragraph("Sklad OLMIKA · Blučina 627, 664 56 Blučina · termín dle potvrzení dodavatele", normal)]], colWidths=[20 * mm, 162 * mm])
    delivery.setStyle(TableStyle([("VALIGN", (0, 0), (-1, -1), "MIDDLE"), ("BOTTOMPADDING", (0, 0), (-1, -1), 3 * mm)]))
    story += [delivery, Spacer(1, 2 * mm)]

    table_head_right = ParagraphStyle("table-head-right", parent=table_head, alignment=TA_RIGHT)
    data = [[Paragraph("Produkt / kód dodavatele", table_head), Paragraph("SKU", table_head), Paragraph("Kart.", table_head_right), Paragraph("Balení", table_head), Paragraph("Kusů", table_head_right), Paragraph("Cena/ks", table_head_right), Paragraph("Celkem", table_head_right)]]
    for name, supplier_code, sku, cartons, pack, unit_price in ROWS:
        supplier_line = f"<br/><font color='#667085'>{supplier_code}</font>" if supplier_code else "<br/><font color='#B42318'>kód dodavatele neuložen</font>"
        data.append([
            Paragraph(f"{name}{supplier_line}", normal), Paragraph(sku, small), Paragraph(str(cartons), right),
            Paragraph(f"Karton {pack} ks", normal), Paragraph(str(cartons * pack), right),
            Paragraph(money(unit_price), right), Paragraph(money(cartons * pack * unit_price), right),
        ])
    table = Table(data, colWidths=[48 * mm, 34 * mm, 11 * mm, 23 * mm, 12 * mm, 23 * mm, 31 * mm], repeatRows=1)
    table_style = [
        ("BACKGROUND", (0, 0), (-1, 0), navy), ("TEXTCOLOR", (0, 0), (-1, 0), colors.white),
        ("FONTNAME", (0, 0), (-1, 0), "AptosNarrow-Bold"), ("VALIGN", (0, 0), (-1, -1), "MIDDLE"),
        ("GRID", (0, 0), (-1, -1), .35, border), ("TOPPADDING", (0, 0), (-1, -1), 2.0 * mm),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 2.0 * mm), ("LEFTPADDING", (0, 0), (-1, -1), 1.7 * mm),
        ("RIGHTPADDING", (0, 0), (-1, -1), 1.7 * mm),
    ]
    for row_index in range(2, len(data), 2):
        table_style.append(("BACKGROUND", (0, row_index), (-1, row_index), pale))
    table.setStyle(TableStyle(table_style))
    story += [table, Spacer(1, 4 * mm)]

    total_cartons = sum(row[3] for row in ROWS)
    total_pieces = sum(row[3] * row[4] for row in ROWS)
    total_net = sum(row[3] * row[4] * row[5] for row in ROWS)
    totals = Table([[Paragraph(f"<b>Celkem {total_cartons} kartonů · {total_pieces} ks</b>", bold), Paragraph(f"<font color='#E1131F'><b>Odhad bez DPH {money(total_net)}</b></font>", right_bold)]], colWidths=[95 * mm, 87 * mm])
    totals.setStyle(TableStyle([("VALIGN", (0, 0), (-1, -1), "MIDDLE"), ("TOPPADDING", (0, 0), (-1, -1), 2 * mm), ("BOTTOMPADDING", (0, 0), (-1, -1), 2 * mm)]))
    note = Table([[Paragraph("NÁVRH – před odesláním prosíme potvrdit dostupnost, aktuální ceny a termín dodání. Uvedené ceny jsou orientační podle interních nákupních karet.", small)]], colWidths=[182 * mm])
    note.setStyle(TableStyle([("BACKGROUND", (0, 0), (-1, -1), colors.HexColor("#FFF5F5")), ("BOX", (0, 0), (-1, -1), .5, colors.HexColor("#FECACA")), ("LEFTPADDING", (0, 0), (-1, -1), 3 * mm), ("RIGHTPADDING", (0, 0), (-1, -1), 3 * mm), ("TOPPADDING", (0, 0), (-1, -1), 2.2 * mm), ("BOTTOMPADDING", (0, 0), (-1, -1), 2.2 * mm)]))
    story.append(KeepTogether([totals, Spacer(1, 2 * mm), note]))
    doc.build(story)


if __name__ == "__main__":
    build()
    print(OUTPUT)
