"""
convert_xml.py  —  AIDE4HF pipeline post-processor
Reads MedTagger .ann files and MedXN _combined.out, writes per-patient XML.

Called by run_model.sh  (Mac/Linux)  or  run_model.bat  (Windows) via:
    python convert_xml.py --in-dir <IN> --out-dir <OUT> --combined <COMBINED>
"""

import argparse
import os
import re
import sys
from xml.dom import minidom

# ─── CLI ────────────────────────────────────────────────────────────────────

parser = argparse.ArgumentParser(description="AIDE4HF XML converter")
parser.add_argument("--in-dir",   required=True, help="Input text directory")
parser.add_argument("--out-dir",  required=True, help="Output directory (contains .ann files)")
parser.add_argument("--combined", required=True, help="MedXN _combined.out path")
args = parser.parse_args()

IN_DIR   = args.in_dir
OUT_DIR  = args.out_dir
COMBINED = args.combined

# ─── Drug-name → HF class mapping ───────────────────────────────────────────
# Keys are lowercase surface forms; values are DTD element names.
# Add entries here as new drugs appear in your corpus.

DRUG_CLASS_MAP = {
    # ── Beta-blockers ─────────────────────────────────────────────────────
    "carvedilol":             "betaBlockers",
    "metoprolol":             "betaBlockers",
    "metoprolol succinate":   "betaBlockers",
    "metoprolol tartrate":    "betaBlockers",
    "bisoprolol":             "betaBlockers",
    "atenolol":               "betaBlockers",
    "nebivolol":              "betaBlockers",
    # ── ACE inhibitors ────────────────────────────────────────────────────
    "lisinopril":             "ACEi",
    "enalapril":              "ACEi",
    "ramipril":               "ACEi",
    "captopril":              "ACEi",
    "fosinopril":             "ACEi",
    "quinapril":              "ACEi",
    "perindopril":            "ACEi",
    "benazepril":             "ACEi",
    "trandolapril":           "ACEi",
    # ── ARBs ─────────────────────────────────────────────────────────────
    "losartan":               "ARB",
    "valsartan":              "ARB",
    "candesartan":            "ARB",
    "irbesartan":             "ARB",
    "olmesartan":             "ARB",
    "telmisartan":            "ARB",
    "azilsartan":             "ARB",
    "eprosartan":             "ARB",
    # ── ARNI ─────────────────────────────────────────────────────────────
    "sacubitril":             "ARNI",
    "sacubitril/valsartan":   "ARNI",
    "entresto":               "ARNI",
    # ── Diuretics ─────────────────────────────────────────────────────────
    "furosemide":             "Diuretics",
    "lasix":                  "Diuretics",
    "torsemide":              "Diuretics",
    "bumetanide":             "Diuretics",
    "ethacrynic acid":        "Diuretics",
    "hydrochlorothiazide":    "Diuretics",
    "hctz":                   "Diuretics",
    "chlorthalidone":         "Diuretics",
    "metolazone":             "Diuretics",
    "indapamide":             "Diuretics",
    # ── MRA ──────────────────────────────────────────────────────────────
    "spironolactone":         "MRA",
    "eplerenone":             "MRA",
    "finerenone":             "MRA",
    # ── SGLT-2 inhibitors ─────────────────────────────────────────────────
    "empagliflozin":          "SGLT",
    "jardiance":              "SGLT",
    "dapagliflozin":          "SGLT",
    "farxiga":                "SGLT",
    "canagliflozin":          "SGLT",
    "invokana":               "SGLT",
    "sotagliflozin":          "SGLT",
    # ── Ivabradine ────────────────────────────────────────────────────────
    "ivabradine":             "Ivabradine",
    "corlanor":               "Ivabradine",
    # ── Vasodilators ──────────────────────────────────────────────────────
    "hydralazine":            "Vasodilator",
    "isosorbide dinitrate":   "Vasodilator",
    "isosorbide mononitrate": "Vasodilator",
    "isosorbide":             "Vasodilator",
    "amlodipine":             "Vasodilator",
    "nitrate":                "Vasodilator",
    "nitroglycerin":          "Vasodilator",
}

def drug_to_class(drug_name):
    """Return HF drug-class tag or None if not an HF medication."""
    return DRUG_CLASS_MAP.get(drug_name.lower().strip())

# ─── Helpers ────────────────────────────────────────────────────────────────

def norm_fname(name):
    """Strip path and remove duplicate-copy suffixes like (1), (2)."""
    name = os.path.basename(name)
    # Normalise Windows backslash remnants that may appear in MedXN output
    name = name.replace("\\", "").replace("/", "")
    name = re.sub(r"\(\d+\)", "", name)
    return name.strip()

def parse_span_field(field):
    """Parse 'text::start::end' → (text, 'start~end'), or ('','') if empty."""
    field = field.strip()
    if not field or "::" not in field:
        return "", ""
    parts = field.split("::")
    text  = parts[0].strip()
    start = parts[1].strip() if len(parts) > 1 else ""
    end   = parts[2].strip() if len(parts) > 2 else ""
    return text, (f"{start}~{end}" if start and end else "")

def parse_frequency_field(field):
    """
    Col 7 may carry multiple frequencies joined by a backtick.
    Each entry is 'text::start::end'.  Returns text values joined by ' | '.
    """
    field = field.strip()
    if not field:
        return ""
    texts = []
    for entry in field.split("`"):
        t, _ = parse_span_field(entry)
        if t:
            texts.append(t)
    return " | ".join(texts)

def set_if(tag, attr, value):
    """Write an XML attribute only when the value is non-empty."""
    if value:
        tag.setAttribute(attr, value)

def parse_kv(line, key):
    """Extract value from key="value" in a MedTagger .ann line."""
    m = re.search(rf'{key}="([^"]*)"', line)
    return m.group(1) if m else ""

def safe_tag(name):
    """Sanitise a norm label into a valid XML element name."""
    name = re.sub(r"[^a-zA-Z0-9_\-.]", "_", name)
    if name and name[0].isdigit():
        name = "_" + name
    return name or "UnknownConcept"

# ─── Load source texts ───────────────────────────────────────────────────────

texts = {}
for fname in os.listdir(IN_DIR):
    path = os.path.join(IN_DIR, fname)
    if os.path.isfile(path):
        texts[norm_fname(fname)] = open(path, encoding="utf-8", errors="ignore").read()

# ─── Parse MedXN (_combined.out) ────────────────────────────────────────────
#
# Pipe-delimited, 12 columns:
#   [0]  filename
#   [1]  name::start::end
#   [2]  rxnorm_cui
#   [3]  dose        (text::start::end)
#   [4]  strength    (raw text)
#   [5]  form        (text::start::end)
#   [6]  route       (text::start::end)
#   [7]  frequency   (backtick-separated text::start::end entries)
#   [8]  duration    (text::start::end)
#   [9]  normalized_name
#   [10] rxnorm_cui_normalized
#   [11] sentence context

medxn = {}

with open(COMBINED, encoding="utf-8", errors="ignore") as f:
    for lineno, line in enumerate(f, 1):
        line = line.strip()
        if not line or "|" not in line:
            continue
        parts = line.split("|")
        if len(parts) < 2 or "::" not in parts[1]:
            continue

        fname = norm_fname(parts[0])

        try:
            med_name, med_start, med_end = parts[1].split("::")[:3]
            med_start, med_end = int(med_start), int(med_end)
        except Exception:
            print(f"⚠️  Skipping malformed name field on line {lineno}: {parts[1]!r}")
            continue

        col = lambda n: parts[n].strip() if len(parts) > n else ""

        dose_text,  _ = parse_span_field(col(3))
        form_text,  _ = parse_span_field(col(5))
        route_text, _ = parse_span_field(col(6))
        dur_text,   _ = parse_span_field(col(8))

        medxn.setdefault(fname, []).append({
            "text":                  med_name,
            "start":                 med_start,
            "end":                   med_end,
            "rxnorm_cui":            col(2),
            "dose":                  dose_text,
            "strength":              col(4),
            "form":                  form_text,
            "route":                 route_text,
            "frequency":             parse_frequency_field(col(7)),
            "duration":              dur_text,
            "normalized_name":       col(9),
            "rxnorm_cui_normalized": col(10),
            "sentence":              col(11),
        })

# ─── Parse MedTagger (.ann files) ───────────────────────────────────────────

medtagger = {}

for fname in os.listdir(OUT_DIR):
    if not fname.endswith(".ann"):
        continue
    key  = norm_fname(fname[:-4])   # strip ".ann"
    path = os.path.join(OUT_DIR, fname)
    with open(path, encoding="utf-8", errors="ignore") as f:
        for i, line in enumerate(f):
            line = line.strip()
            if not line:
                continue
            cols = line.split("\t")
            if len(cols) < 4 or cols[2].strip() != "CM":
                continue
            try:
                norm_label = parse_kv(line, "norm")
                if not norm_label:
                    print(f"⚠️  Missing norm on .ann line {i+1}, skipping")
                    continue
                medtagger.setdefault(key, []).append({
                    "id":          f"T{i}",
                    "label":       norm_label,
                    "text":        parse_kv(line, "text"),
                    "start":       int(parse_kv(line, "start")),
                    "end":         int(parse_kv(line, "end")),
                    "certainty":   parse_kv(line, "certainty"),
                    "status":      parse_kv(line, "status"),
                    "experiencer": parse_kv(line, "experiencer"),
                    "sentence":    parse_kv(line, "sentence"),
                })
            except Exception as e:
                print(f"⚠️  Skipping malformed .ann line {i+1}: {e}")

# ─── Debug summary ───────────────────────────────────────────────────────────

print("\n=== DEBUG INFO ===")
print("TEXT FILES:      ", list(texts.keys()))
print("MEDTAGGER FILES: ", list(medtagger.keys()))
print("MEDXN FILES:     ", list(medxn.keys()))
print("MEDTAGGER COUNTS:", {k: len(v) for k, v in medtagger.items()})
print("MEDXN COUNTS:    ", {k: len(v) for k, v in medxn.items()})

for fname, entries in medxn.items():
    mapped   = [(e["text"], drug_to_class(e["text"])) for e in entries]
    unmapped = [t for t, c in mapped if c is None]
    print(f"MEDXN MAPPING [{fname}]:",
          {t: c for t, c in mapped},
          f"-> fallback <Medication>: {unmapped}" if unmapped else "-> all mapped")
print("==================\n")

# ─── Build XML ───────────────────────────────────────────────────────────────

CERTAINTY_MAP = {
    "Positive": "confirmed",
    "Negated":  "negated",
    "Possible": "possible",
    "Hedged":   "hypothetical",
}

def add_prescription_attrs(tag, m):
    """Write prescription detail attributes onto a drug-class or Medication tag."""
    set_if(tag, "rxnorm_cui",            m["rxnorm_cui"])
    set_if(tag, "dose",                  m["dose"])
    set_if(tag, "strength",              m["strength"])
    set_if(tag, "form",                  m["form"])
    set_if(tag, "route",                 m["route"])
    set_if(tag, "frequency",             m["frequency"])
    set_if(tag, "duration",              m["duration"])
    set_if(tag, "normalized_name",       m["normalized_name"])
    set_if(tag, "rxnorm_cui_normalized", m["rxnorm_cui_normalized"])

def build_xml(fname, text):
    doc  = minidom.Document()
    root = doc.createElement("AIDE4HF_schema_1_0")
    doc.appendChild(root)

    text_elem = doc.createElement("TEXT")
    text_elem.appendChild(doc.createCDATASection(text))
    root.appendChild(text_elem)

    tags_elem = doc.createElement("TAGS")
    root.appendChild(tags_elem)

    # ── MedTagger concept annotations (symptoms / findings) ──────────────
    if medtagger.get(fname):
        tags_elem.appendChild(doc.createComment(
            " ==================== MEDTAGGER ENTITIES ==================== "
        ))
        for ann in medtagger[fname]:
            tag = doc.createElement(safe_tag(ann["label"]))
            tag.setAttribute("spans",      f"{ann['start']}~{ann['end']}")
            tag.setAttribute("text",       ann["text"])
            tag.setAttribute("id",         ann["id"])
            tag.setAttribute("certainty",
                CERTAINTY_MAP.get(ann["certainty"], ann["certainty"].lower()))
            tag.setAttribute("status",      ann["status"].lower())
            tag.setAttribute("experiencer", ann["experiencer"].lower())
            tag.setAttribute("exclusion",   "no")
            tag.setAttribute("comment",     ann.get("sentence", "NA"))
            tags_elem.appendChild(tag)

    # ── MedXN medications → mapped to HF class tags ──────────────────────
    if medxn.get(fname):
        tags_elem.appendChild(doc.createComment(
            " ==================== MEDXN MEDICATIONS ==================== "
        ))
        for i, m in enumerate(medxn[fname]):
            hf_class = drug_to_class(m["text"])
            tag = doc.createElement(hf_class if hf_class else "Medication")
            tag.setAttribute("spans", f"{m['start']}~{m['end']}")
            tag.setAttribute("text",  m["text"])
            tag.setAttribute("id",    f"M{i}")
            add_prescription_attrs(tag, m)
            tag.setAttribute("certainty",   "confirmed")
            tag.setAttribute("status",      "present")
            tag.setAttribute("experiencer", "patient")
            tag.setAttribute("exclusion",   "no")
            tag.setAttribute("comment",     m["sentence"] if m["sentence"] else "NA")
            tags_elem.appendChild(tag)

    meta     = doc.createElement("META")
    label_el = doc.createElement("label")
    label_el.setAttribute("color", "yellow")
    meta.appendChild(label_el)
    root.appendChild(meta)

    return doc.toprettyxml(indent="  ", encoding="utf-8")

# ─── Write output XML files ──────────────────────────────────────────────────

written = 0
for fname, text in texts.items():
    xml      = build_xml(fname, text)
    out_path = os.path.join(OUT_DIR, fname + ".xml")
    with open(out_path, "wb") as f:
        f.write(xml)
    print(f"  Wrote: {out_path}")
    written += 1

if written == 0:
    print("⚠️  No XML files written — check that IN_DIR contains input text files.")
    sys.exit(1)

print("✅ XML generation COMPLETE")
