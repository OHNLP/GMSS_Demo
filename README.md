# GMSS Demo — AIDE4HF NLP Pipeline

> **Workshop demo repository** for the AIDE4HF project  
> *AI-Driven Detection of Adverse Drug Events in Heart Failure Patients*  
> UTHealth Houston · McGovern Medical School & McWilliams School of Biomedical Informatics

---

## Overview

AIDE4HF is an NIH R21-funded hybrid NLP pipeline that automatically extracts **heart failure (HF) medications**, **clinical symptoms**, and **adverse drug event (ADE) signals** from free-text clinical notes in electronic health records (EHR).

This repository provides a self-contained demo for workshop participants to run the full pipeline on a sample patient note and inspect the structured XML output.

---

## Pipeline Architecture

```
Clinical Notes (plain text)
        │
        ▼
┌───────────────────┐
│   MedTaggerIE     │  ← Extracts HF symptoms & drug-class findings
│  (rule-based NLP) │    Output: per-note  .ann  files
└───────────────────┘
        │
        ▼
┌───────────────────┐
│     MedXN         │  ← Extracts medication names + prescription detail
│  (dictionary NLP) │    (dose, route, frequency, duration, RxNorm CUI)
└───────────────────┘    Output: _combined.out
        │
        ▼
┌───────────────────┐
│  convert_xml.py   │  ← Merges both outputs into structured XML
│  (post-processor) │    Drug names mapped to HF drug-class tags
└───────────────────┘
        │
        ▼
  Per-patient  .xml  (AIDE4HF_schema_1_0)
```

---

## Repository Structure

```
GMSS_Demo/
├── input/                          # Sample patient note(s) — plain text
├── models/
│   └── AITC/                       # MedTaggerIE rule files
├── output/                         # Pipeline outputs (generated at runtime)
│   ├── *.ann                       # MedTagger annotation files
│   ├── _combined.out               # MedXN combined output
│   └── *.xml                       # Final structured XML (one per note)
├── AITC.dtd                        # XML schema definition
├── AIDE4HF_Annotation_Guidelines_v1.0.docx   # Annotator reference guide
├── convert_xml.py                  # Python post-processor (cross-platform)
├── run_model.sh                    # Pipeline launcher — Mac / Linux
└── run_model.bat                   # Pipeline launcher — Windows
```

---

## Requirements

| Dependency | Version | Notes |
|---|---|---|
| Java (JDK) | 8 or 11 | Required for MedTagger and MedXN |
| Python | 3.7+ | Standard library only — no extra packages needed |
| OS | macOS, Linux, Windows 10+ | See platform notes below |

---

## Quick Start

### 1. Clone the repository

```bash
git clone https://github.com/OHNLP/GMSS_Demo.git
cd GMSS_Demo
```

### 2. Add the JAR files

Download and place in the repo root:
- `MedTagger-fit-context.jar`
- `MedXN-2/MedXN.jar` (inside a `MedXN-2/` subfolder)
- `resources/` (MedXN resource files, inside a `resources/` subfolder)

### 3. Run the pipeline

**Mac / Linux:**
```bash
bash run_model.sh
```

**Windows:**
```bat
run_model.bat
```

Both launchers accept optional path overrides:
```bash
# Mac/Linux
bash run_model.sh /path/to/input /path/to/output /path/to/models/AITC

# Windows
run_model.bat C:\path\to\input C:\path\to\output C:\path\to\models\AITC
```

### 4. Inspect the output

After the pipeline completes, each input note will have a corresponding `.xml` file in `output/`. Open it in any text editor or XML viewer.

---

## Output XML Format

Each output file follows the `AIDE4HF_schema_1_0` format defined in `AITC.dtd`:

```xml
<AIDE4HF_schema_1_0>
  <TEXT><![CDATA[ ...raw note text... ]]></TEXT>
  <TAGS>
    <!-- MedTaggerIE concept annotations -->
    <HFSymptoms spans="333~338" text="edema" id="T1"
      certainty="confirmed" status="present" experiencer="patient"
      exclusion="no" comment="bilateral lower extremity edema noted"/>

    <!-- MedXN medication annotations, mapped to HF drug-class tags -->
    <Diuretics spans="1204~1209" text="Lasix" id="M4"
      rxnorm_cui="202991" dose="40 mg" route="p.o."
      frequency="daily | as needed" duration="5 days"
      certainty="confirmed" status="present" experiencer="patient"
      exclusion="no" comment="..."/>

    <betaBlockers spans="1499~1509" text="carvedilol" id="M6"
      rxnorm_cui="20352" dose="12.5 mg" route="p.o."
      frequency="twice daily" normalized_name="carvedilol 12.5 MG"
      rxnorm_cui_normalized="315575"
      certainty="confirmed" status="present" experiencer="patient"
      exclusion="no" comment="..."/>
  </TAGS>
</AIDE4HF_schema_1_0>
```

### Supported HF Drug-Class Tags

| Tag | Drug Class | Example Drugs |
|---|---|---|
| `betaBlockers` | Beta-blockers | carvedilol, metoprolol, bisoprolol |
| `ACEi` | ACE inhibitors | lisinopril, enalapril, ramipril |
| `ARB` | Angiotensin receptor blockers | losartan, valsartan, azilsartan |
| `ARNI` | Angiotensin receptor-neprilysin inhibitor | sacubitril/valsartan (Entresto) |
| `Diuretics` | Diuretics | furosemide (Lasix), torsemide, chlorthalidone |
| `MRA` | Mineralocorticoid receptor antagonists | spironolactone, eplerenone |
| `SGLT` | SGLT-2 inhibitors | empagliflozin, dapagliflozin |
| `Ivabradine` | Ivabradine | ivabradine (Corlanor) |
| `Vasodilator` | Vasodilators | hydralazine, isosorbide, amlodipine |
| `HFSymptoms` | HF symptoms / clinical findings | edema, dyspnea, bradycardia |
| `Medication` | Non-HF drugs (fallback) | any drug not in the above classes |

---

## Annotation Guidelines

See [`AIDE4HF_Annotation_Guidelines_v1.0.docx`](./AIDE4HF_Annotation_Guidelines_v1.0.docx) for the full annotator reference, including:

- Concept and medication tag definitions
- Attribute decision rules (`certainty`, `status`, `experiencer`)
- ADE determination decision tree (5-step logic)
- Inter-annotator agreement targets (κ ≥ 0.8)
- Edge cases and common pitfalls

---

## Troubleshooting

**`java` not found** — Install the JDK and ensure it is on your system `PATH`.  
Check with: `java -version`

**`python` / `python3` not found** — Install Python 3.7+ from [python.org](https://www.python.org/downloads/).  
Check with: `python --version`

**Empty output / no `.xml` files generated** — Check `output/pipeline.log` for error details from MedTagger or MedXN.

**Drug mapped to `<Medication>` instead of a class tag** — The drug name is not yet in the `DRUG_CLASS_MAP` dictionary in `convert_xml.py`. Add an entry following the existing pattern.

---

## Citation

If you use this pipeline in your research, please cite:

> Kwak S, Fu S, et al. *AIDE4HF: AI-Driven Detection of Adverse Drug Events in Heart Failure Patients.* NIH R21 Project, UTHealth Houston, 2024.

---

## License

This repository is intended for workshop and research demonstration purposes.  
For licensing inquiries please contact the OHNLP group at UTHealth Houston.

---

## Contact

**PI:** Dr. Sunghwan Sohn Fu — McWilliams School of Biomedical Informatics, UTHealth Houston  
**Co-PI:** Dr. Seongkum Kwak — McGovern Medical School, Division of Geriatric Medicine  
**Organization:** [OHNLP GitHub](https://github.com/OHNLP)
