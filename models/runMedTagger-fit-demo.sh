#/bin/bash


INPUT_DIR="/Users/sfu3/Desktop/GMSS/input"
OUTPUT_DIR="/Users/sfu3/Desktop/GMSS/output"
RULES_DIR="/Users/sfu3/Desktop/GMSS/models/AITC"

java -Xms512M -Xmx2000M -jar MedTagger-fit-context.jar $INPUT_DIR $OUTPUT_DIR $RULES_DIR


