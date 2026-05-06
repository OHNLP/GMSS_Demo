#!/usr/bin/env bash
# run_model.sh — AIDE4HF pipeline launcher for Mac / Linux
# Usage: bash run_model.sh [IN_DIR] [OUT_DIR] [RULES_DIR]
#   All three arguments are optional; they override the defaults below.
set -euo pipefail

# ── Resolve script location so the script works from any working directory ──
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ═══════════════════════════════════════════════════════════════════
#  CONFIG  — edit these defaults or pass them as positional args
# ═══════════════════════════════════════════════════════════════════
IN_DIR="${1:-/Users/sfu3/Desktop/GMSS/input}"
OUT_DIR="${2:-/Users/sfu3/Desktop/GMSS/output}"
RULES_DIR="${3:-/Users/sfu3/Desktop/GMSS/models/AITC}"

CLASSPATH="$SCRIPT_DIR/resources:$SCRIPT_DIR/MedXN-2/MedXN.jar"
COMBINED="$OUT_DIR/_combined.out"
LOG="$OUT_DIR/pipeline.log"
CONVERTER="$SCRIPT_DIR/convert_xml.py"

# ── Pre-flight checks ────────────────────────────────────────────────────────
for req in java python3; do
  if ! command -v "$req" &>/dev/null; then
    echo "❌ '$req' not found on PATH. Please install it and try again."
    exit 1
  fi
done

if [[ ! -f "$CONVERTER" ]]; then
  echo "❌ convert_xml.py not found at: $CONVERTER"
  exit 1
fi

if [[ ! -d "$IN_DIR" ]]; then
  echo "❌ Input directory not found: $IN_DIR"
  exit 1
fi

# ── Setup ────────────────────────────────────────────────────────────────────
mkdir -p "$OUT_DIR"
# Rotate previous log rather than appending forever
[[ -f "$LOG" ]] && mv "$LOG" "${LOG%.log}_prev.log"
rm -f "$OUT_DIR"/*.xml "$COMBINED"

echo "================================================"
echo "  AIDE4HF Pipeline"
echo "  IN  : $IN_DIR"
echo "  OUT : $OUT_DIR"
echo "  Rules: $RULES_DIR"
echo "================================================"

# ── Step 1: MedTagger ────────────────────────────────────────────────────────
echo "[1/3] Running MedTagger..."
if ! java -Xms512M -Xmx2000M -jar "$SCRIPT_DIR/MedTagger-fit-context.jar" \
       "$IN_DIR" "$OUT_DIR" "$RULES_DIR" >>"$LOG" 2>&1; then
  echo "❌ MedTagger failed — check $LOG"
  exit 1
fi
echo "      MedTagger done."

# ── Step 2: MedXN ────────────────────────────────────────────────────────────
echo "[2/3] Running MedXN..."
if ! java -cp "$CLASSPATH" org.ohnlp.medxn.Main \
       "$IN_DIR" "$COMBINED" >>"$LOG" 2>&1; then
  echo "❌ MedXN failed — check $LOG"
  exit 1
fi

if [[ ! -s "$COMBINED" ]]; then
  echo "❌ MedXN produced an empty output file — check $LOG"
  exit 1
fi
echo "      MedXN done. ($(wc -l < "$COMBINED") entries)"

# ── Step 3: Convert to XML ───────────────────────────────────────────────────
echo "[3/3] Converting to XML..."
if ! python3 "$CONVERTER" \
       --in-dir   "$IN_DIR"   \
       --out-dir  "$OUT_DIR"  \
       --combined "$COMBINED" 2>&1 | tee -a "$LOG"; then
  echo "❌ XML conversion failed — check $LOG"
  exit 1
fi

echo "================================================"
echo "✅ Pipeline complete. Output: $OUT_DIR"
echo "================================================"
