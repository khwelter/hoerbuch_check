#!/bin/bash

# Standardwerte
SILENCE_START_TARGET=""
SILENCE_END_TARGET=""
TOLERANCE=10  # in Prozent
SILENCE_THRESHOLD="-40"  # dB
TARGET_FILES=()

# Farben für die Ausgabe
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Hilfe-Funktion
show_help() {
    cat << EOF
Verwendung: $(basename "$0") [OPTIONEN] [DATEI...]

Überprüft die Stille am Anfang und Ende von WAV-Dateien.

OPTIONEN:
  -s SEKUNDEN       Ziel-Stille am Anfang in Sekunden (z.B. 0.5)
  -e SEKUNDEN       Ziel-Stille am Ende in Sekunden (z.B. 1.0)
  -t PROZENT        Toleranz in Prozent (Standard: 10)
  -l DB_WERT        Schwellwert für Stille in dB (Standard: -40)
  -h, --help        Zeigt diese Hilfe an

ARGUMENTE:
  DATEI...          Eine oder mehrere WAV-Dateien
                    Ohne Angabe: alle WAV-Dateien im aktuellen Verzeichnis

BEISPIELE:
  $(basename "$0") -s 0.5 -e 1.0                    # Alle WAV-Dateien, 0.5s Anfang, 1.0s Ende
  $(basename "$0") -s 0.5 -e 1.0 -t 15 audio.wav    # Einzelne Datei, 15% Toleranz
  $(basename "$0") -l -50 -s 1.0 -e 1.0 *.wav       # Alle WAV-Dateien, -50dB Schwelle

FARBCODIERUNG:
  GRÜN  = Stille liegt innerhalb der Toleranz
  ROT   = Stille liegt außerhalb der Toleranz

EOF
    exit 0
}

# Parameter parsen
while [[ $# -gt 0 ]]; do
    case $1 in
        -s)
            SILENCE_START_TARGET="$2"
            shift 2
            ;;
        -e)
            SILENCE_END_TARGET="$2"
            shift 2
            ;;
        -t)
            TOLERANCE="$2"
            shift 2
            ;;
        -l)
            SILENCE_THRESHOLD="$2"
            shift 2
            ;;
        -h|--help)
            show_help
            ;;
        *)
            TARGET_FILES+=("$1")
            shift
            ;;
    esac
done

# Prüfen ob ffmpeg installiert ist
if ! command -v ffmpeg &> /dev/null; then
    echo -e "${RED}FEHLER: ffmpeg ist nicht installiert!${NC}"
    echo "Installieren Sie es mit: brew install ffmpeg"
    exit 1
fi

echo "=========================================="
echo "Stille-Checker für Audio-Dateien"
echo "=========================================="
echo ""
echo "Einstellungen:"
if [ -n "$SILENCE_START_TARGET" ]; then
    echo "  • Ziel-Stille Anfang: ${SILENCE_START_TARGET}s"
fi
if [ -n "$SILENCE_END_TARGET" ]; then
    echo "  • Ziel-Stille Ende:   ${SILENCE_END_TARGET}s"
fi
echo "  • Toleranz:           ${TOLERANCE}%"
echo "  • Schwellwert:        ${SILENCE_THRESHOLD} dB"
echo ""

# Funktion zur Berechnung der Toleranzgrenzen
calculate_limits() {
    local target=$1
    local tolerance=$2
    
    # Sicherstellen dass target und tolerance gültige Zahlen sind
    if [ -z "$target" ] || [ -z "$tolerance" ]; then
        echo "0|0"
        return
    fi
    
    local lower=$(awk "BEGIN {printf \"%.2f\", $target * (1 - $tolerance/100)}")
    local upper=$(awk "BEGIN {printf \"%.2f\", $target * (1 + $tolerance/100)}")
    
    echo "$lower|$upper"
}

# Funktion zur Überprüfung ob Wert in Toleranz liegt
check_tolerance() {
    local value=$1
    local target=$2
    local tolerance=$3
    
    # Wenn kein Zielwert gesetzt ist, überspringen
    if [ -z "$target" ]; then
        echo "skip"
        return
    fi
    
    # Wenn value leer oder ungültig ist, als "no" markieren
    if [ -z "$value" ]; then
        echo "no"
        return
    fi
    
    local limits=$(calculate_limits "$target" "$tolerance")
    IFS='|' read -r lower upper <<< "$limits"
    
    # Prüfen ob lower und upper gültig sind
    if [ -z "$lower" ] || [ -z "$upper" ]; then
        echo "no"
        return
    fi
    
    local in_range=$(awk -v val="$value" -v low="$lower" -v up="$upper" 'BEGIN {if (val >= low && val <= up) print "yes"; else print "no"}')
    echo "$in_range"
}

# Funktion zur Erkennung von Stille am Anfang und Ende
detect_silence() {
    local file="$1"
    local threshold="$2"
    
    # ffmpeg silencedetect verwenden
    local silence_data=$(ffmpeg -i "$file" -af "silencedetect=noise=${threshold}dB:d=0.01" -f null - 2>&1)
    
    # Erste Stille (am Anfang) - prüfen ob Datei mit Stille beginnt
    local first_silence_end=$(echo "$silence_data" | grep "silence_end" | head -1 | sed -n 's/.*silence_end: \([0-9.]*\).*/\1/p')
    local first_silence_start=$(echo "$silence_data" | grep "silence_start" | head -1 | sed -n 's/.*silence_start: \([0-9.]*\).*/\1/p')
    
    # Stille am Anfang nur wenn die erste Stille bei 0 beginnt
    local silence_start="0.00"
    if [ -n "$first_silence_start" ]; then
        # Prüfen ob erste Stille nahe bei 0 beginnt (innerhalb 0.1 Sekunden)
        local is_near_zero=$(awk -v val="$first_silence_start" 'BEGIN {if (val < 0.1) print "yes"; else print "no"}')
        if [ "$is_near_zero" = "yes" ] && [ -n "$first_silence_end" ]; then
            silence_start="$first_silence_end"
        fi
    fi
    
    # Gesamtdauer ermitteln
    local duration=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$file" 2>/dev/null)
    
    # Letzte Stille (am Ende)
    local last_silence_start=$(echo "$silence_data" | grep "silence_start" | tail -1 | sed -n 's/.*silence_start: \([0-9.]*\).*/\1/p')
    
    # Stille am Ende berechnen
    local silence_end="0.00"
    if [ -n "$last_silence_start" ] && [ -n "$duration" ]; then
        silence_end=$(awk -v dur="$duration" -v start="$last_silence_start" 'BEGIN {printf "%.2f", dur - start}')
    fi
    
    # Auf 2 Nachkommastellen formatieren
    silence_start=$(printf "%.2f" "$silence_start" 2>/dev/null || echo "0.00")
    silence_end=$(printf "%.2f" "$silence_end" 2>/dev/null || echo "0.00")
    
    echo "$silence_start|$silence_end"
}

# Funktion zum Verarbeiten einer einzelnen Datei
process_file() {
    local wavfile="$1"
    local filename=$(basename "$wavfile")
    
    if [ ! -f "$wavfile" ]; then
        echo -e "${RED}FEHLER: Datei '$wavfile' existiert nicht${NC}"
        return
    fi
    
    # Stille erkennen
    local silence_result=$(detect_silence "$wavfile" "$SILENCE_THRESHOLD")
    IFS='|' read -r silence_start silence_end <<< "$silence_result"
    
    # Toleranz prüfen für Anfang
    local start_status=$(check_tolerance "$silence_start" "$SILENCE_START_TARGET" "$TOLERANCE")
    
    # Toleranz prüfen für Ende
    local end_status=$(check_tolerance "$silence_end" "$SILENCE_END_TARGET" "$TOLERANCE")
    
    # Gesamtstatus bestimmen
    local overall_status="ok"
    if [ "$start_status" = "no" ] || [ "$end_status" = "no" ]; then
        overall_status="fail"
    fi
    
    # Farbcodierung
    local color=$GREEN
    if [ "$overall_status" = "fail" ]; then
        color=$RED
    fi
    
    # Ausgabe
    echo -e "${BLUE}======================================${NC}"
    echo -e "${color}Datei: $filename${NC}"
    echo -e "${BLUE}======================================${NC}"
    
    # Stille am Anfang
    if [ -n "$SILENCE_START_TARGET" ]; then
        local start_color=$GREEN
        if [ "$start_status" = "no" ]; then
            start_color=$RED
        fi
        echo -e "  • Stille am Anfang:  ${start_color}${silence_start}s${NC} (Ziel: ${SILENCE_START_TARGET}s ±${TOLERANCE}%)"
    else
        echo -e "  • Stille am Anfang:  ${silence_start}s"
    fi
    
    # Stille am Ende
    if [ -n "$SILENCE_END_TARGET" ]; then
        local end_color=$GREEN
        if [ "$end_status" = "no" ]; then
            end_color=$RED
        fi
        echo -e "  • Stille am Ende:    ${end_color}${silence_end}s${NC} (Ziel: ${SILENCE_END_TARGET}s ±${TOLERANCE}%)"
    else
        echo -e "  • Stille am Ende:    ${silence_end}s"
    fi
    
    # Status-Symbol
    if [ -n "$SILENCE_START_TARGET" ] || [ -n "$SILENCE_END_TARGET" ]; then
        if [ "$overall_status" = "ok" ]; then
            echo -e "  • Status:            ${GREEN}✓ OK${NC}"
        else
            echo -e "  • Status:            ${RED}✗ Außerhalb Toleranz${NC}"
        fi
    fi
    
    echo ""
}

# Dateien sammeln
files_to_process=()

if [ ${#TARGET_FILES[@]} -eq 0 ]; then
    # Keine Dateien angegeben, alle WAV-Dateien im aktuellen Verzeichnis
    for wavfile in *.wav; do
        if [ -f "$wavfile" ]; then
            files_to_process+=("$wavfile")
        fi
    done
else
    # Angegebene Dateien verwenden
    files_to_process=("${TARGET_FILES[@]}")
fi

# Prüfen ob Dateien gefunden wurden
if [ ${#files_to_process[@]} -eq 0 ]; then
    echo -e "${RED}Keine WAV-Dateien gefunden.${NC}"
    exit 1
fi

# Dateien verarbeiten
for wavfile in "${files_to_process[@]}"; do
    process_file "$wavfile"
done

echo "=========================================="
echo "Verarbeitung abgeschlossen!"
echo "=========================================="

