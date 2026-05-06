#!/usr/bin/env bash
set -euo pipefail

# ---------- Config ----------
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
IN_DIR="/Users/sfu3/Desktop/GMSS/input"
OUT_DIR="/Users/sfu3/Desktop/GMSS/output"

CLASSPATH="$SCRIPT_DIR/resources:$SCRIPT_DIR/MedXN.jar"
COMBINED="$OUT_DIR/_combined.out"

# Splitter choice: awk | python
SPLITTER="${SPLITTER:-awk}"   # set SPLITTER=python to use Python splitter

# ---------- Helpers ----------
fmt_time() {
  local s=$1
  printf "%02d:%02d:%02d" $((s/3600)) $(((s%3600)/60)) $((s%60))
}

split_with_awk() {
  echo "Splitting (awk) $COMBINED -> $OUT_DIR ..."
  awk -v OUTDIR="$OUT_DIR" '
  BEGIN { IGNORECASE=1; current_out="" }
  {
    line = $0
    p = index(line, "|")
    if (p > 0) {
      hdr = substr(line, 1, p-1)

      # trim quotes/space
      gsub(/^"+|"+$/, "", hdr)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", hdr)

      # normalize separators
      gsub("\\\\", "/", hdr)

      # basename only
      sub(/^.*\//, "", hdr)

      if (hdr == "") {
        if (current_out != "") { print line >> current_out }
        next
      }

      base = hdr

      # FIXED LINES
      sub(/\.[^.\/[:space:]]+$/, "", base)
      sub(/\.[^.\/[:space:]]+$/, "", base)

      if (base == "") base = "unknown"

      current_out = OUTDIR "/" base "_out.txt"
      print line >> current_out
    } else {
      if (current_out != "") { print line >> current_out }
    }
  }' "$COMBINED"
}

split_with_python() {
  echo "Splitting (python) $COMBINED -> $OUT_DIR ..."
  OUT_DIR="$OUT_DIR" COMBINED="$COMBINED" python3 - <<'PY'
import os, re

OUT_DIR = os.environ["OUT_DIR"]
COMBINED = os.environ["COMBINED"]
os.makedirs(OUT_DIR, exist_ok=True)

def clean_basename(hdr: str) -> str:
    hdr = hdr.strip().strip('"').replace("\\", "/")
    hdr = hdr.rsplit("/", 1)[-1] or "unknown"
    # strip up to two extensions (e.g., .txt, .txt.gz, .out)
    for _ in range(2):
        hdr = re.sub(r"\.[^./\s]+$", "", hdr)
    return hdr or "unknown"

current = None
with open(COMBINED, "r", encoding="utf-8", errors="ignore") as f:
    for line in f:
        if "|" in line:
            hdr, _ = line.split("|", 1)
            base = clean_basename(hdr)
            current = os.path.join(OUT_DIR, f"{base}_out.txt")
        if current:
            with open(current, "a", encoding="utf-8") as w:
                w.write(line)
PY
}

# ---------- Run ----------
mkdir -p "$OUT_DIR"

TOTAL_START=$(date +%s)

echo "Running MedXN once over: $IN_DIR"
MEDXN_START=$(date +%s)
# If you want logs, remove redirection to /dev/null
java -cp "$CLASSPATH" org.ohnlp.medxn.Main "$IN_DIR" "$COMBINED" >/dev/null 2>&1
MEDXN_END=$(date +%s)

if [[ ! -s "$COMBINED" ]]; then
  echo "❌ Combined output not found or empty: $COMBINED"
  exit 1
fi

# Decide which splitter to use
case "$SPLITTER" in
  python) split_with_python ;;
  awk)    split_with_awk ;;
  *)      echo "Unknown SPLITTER='$SPLITTER' (use 'awk' or 'python')" >&2; exit 2 ;;
esac

TOTAL_END=$(date +%s)

echo "✅ Done."
echo "  MedXN runtime : $(fmt_time $((MEDXN_END - MEDXN_START)))"
echo "  Total runtime : $(fmt_time $((TOTAL_END - TOTAL_START)))"
echo "  Output dir    : $OUT_DIR"
