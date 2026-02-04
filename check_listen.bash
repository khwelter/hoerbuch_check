#!/bin/bash

# Verzeichnis mit den WAV-Dateien (Standard: aktuelles Verzeichnis)
AUDIO_DIR="."
PLAY_START=true
PLAY_END=true
TARGET_PATH=""

# Temporäres Verzeichnis für Audioschnipsel
TEMP_DIR="/tmp/audio_check_$$"
mkdir -p "$TEMP_DIR"

# Cleanup-Funktion
cleanup() {
    rm -rf "$TEMP_DIR"
}
trap cleanup EXIT

# Farben für die Ausgabe
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Hilfe-Funktion
show_help() {
    cat << EOF
Verwendung: $(basename "$0") [OPTIONEN] [DATEI/VERZEICHNIS]

Audio-Checker für ACX-Standards - Spielt die ersten und letzten 10 Sekunden
von WAV-Dateien ab und führt einen ACX Audio Check durch.

OPTIONEN:
  --anfang          Spielt nur die ersten 10 Sekunden ab
  --ende            Spielt nur die letzten 10 Sekunden ab
  -h, --help        Zeigt diese Hilfe an

ARGUMENTE:
  DATEI             Einzelne WAV-Datei zum Überprüfen
  VERZEICHNIS       Verzeichnis mit WAV-Dateien (Standard: aktuelles Verzeichnis)

BEISPIELE:
  $(basename "$0")                          # Alle WAV-Dateien im aktuellen Verzeichnis
  $(basename "$0") audio.wav                # Einzelne Datei überprüfen
  $(basename "$0") /pfad/zum/verzeichnis    # Verzeichnis angeben
  $(basename "$0") --anfang audio.wav       # Nur erste 10 Sekunden
  $(basename "$0") --ende /pfad/zum/dir     # Nur letzte 10 Sekunden aller Dateien

EOF
    exit 0
}

# Parameter parsen
while [[ $# -gt 0 ]]; do
    case $1 in
        --anfang)
            PLAY_START=true
            PLAY_END=false
            shift
            ;;
        --ende)
            PLAY_START=false
            PLAY_END=true
            shift
            ;;
        -h|--help)
            show_help
            ;;
        *)
            TARGET_PATH="$1"
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
echo "Audio-Checker für ACX-Standards"
echo "=========================================="
echo ""

# Funktion für Pieptöne
beep() {
    local count=$1
    for ((i=1; i<=count; i++)); do
        afplay /System/Library/Sounds/Tink.aiff
        sleep 0.2
    done
}

# Funktion für ACX Audio Check
acx_check() {
    local file="$1"
    
    # RMS (Lautheit) berechnen
    rms=$(ffmpeg -i "$file" -af "volumedetect" -vn -sn -dn -f null /dev/null 2>&1 | \
          grep "mean_volume" | awk '{print $5}')
    
    # Peak Level berechnen
    peak=$(ffmpeg -i "$file" -af "volumedetect" -vn -sn -dn -f null /dev/null 2>&1 | \
           grep "max_volume" | awk '{print $5}')
    
    # Noise Floor berechnen (über silencedetect)
    noise=$(ffmpeg -i "$file" -af "silencedetect=noise=-60dB:d=0.1" -f null - 2>&1 | \
            grep "silence_start" | head -1 | grep -oE '\-[0-9\.]+' | head -1)
    
    if [ -z "$noise" ]; then
        noise="-60.00"
    fi
    
    # Auf 2 Nachkommastellen formatieren
    rms_formatted=$(printf "%.2f" "$rms" 2>/dev/null || echo "$rms")
    peak_formatted=$(printf "%.2f" "$peak" 2>/dev/null || echo "$peak")
    noise_formatted=$(printf "%.2f" "$noise" 2>/dev/null || echo "$noise")
    
    echo "$rms_formatted|$peak_formatted|$noise_formatted"
}

# Funktion zum Verarbeiten einer einzelnen Datei
process_file() {
    local wavfile="$1"
    local filename=$(basename "$wavfile")
    
    echo -e "${BLUE}======================================${NC}"
    echo -e "${GREEN}Datei: $filename${NC}"
    echo -e "${BLUE}======================================${NC}"
    
    # Dauer der Datei ermitteln
    duration=$(ffprobe -v error -show_entries format=duration \
               -of default=noprint_wrappers=1:nokey=1 "$wavfile" 2>/dev/null)
    
    if [ -z "$duration" ]; then
        echo -e "${RED}FEHLER: Kann Datei nicht lesen oder keine gültige Audio-Datei${NC}"
        echo ""
        return
    fi
    
    duration_int=${duration%.*}
    
    # ACX Audio Check durchführen
    echo -e "${YELLOW}Führe ACX Audio Check durch...${NC}"
    acx_result=$(acx_check "$wavfile")
    IFS='|' read -r rms_value peak_value noise_value <<< "$acx_result"
    
    echo ""
    echo "ACX Parameter:"
    echo "  • RMS (Durchschnittslautstärke): ${rms_value} dB"
    echo "  • Peak Level (Maximalpegel):     ${peak_value} dB"
    echo "  • Noise Floor (Grundrauschen):   ${noise_value} dB"
    echo ""
    
    # Erste 10 Sekunden abspielen
    if [ "$PLAY_START" = true ]; then
        echo "► Spiele erste 10 Sekunden ab..."
        beep 1
        first_10="${TEMP_DIR}/first_10.wav"
        ffmpeg -i "$wavfile" -t 10 -y "$first_10" 2>/dev/null
        afplay "$first_10"
    fi
    
    # Letzte 10 Sekunden abspielen
    if [ "$PLAY_END" = true ]; then
        if [ "$duration_int" -gt 10 ]; then
            start_time=$((duration_int - 10))
            echo "► Spiele letzte 10 Sekunden ab..."
            beep 2
            last_10="${TEMP_DIR}/last_10.wav"
            ffmpeg -ss "$start_time" -i "$wavfile" -y "$last_10" 2>/dev/null
            afplay "$last_10"
        else
            echo "⚠ Datei ist kürzer als 10 Sekunden, überspringe letzte 10 Sekunden."
        fi
    fi
    
    echo ""
}

# Bestimmen, was verarbeitet werden soll
if [ -z "$TARGET_PATH" ]; then
    # Kein Pfad angegeben, verwende aktuelles Verzeichnis
    TARGET_PATH="."
fi

if [ -f "$TARGET_PATH" ]; then
    # Einzelne Datei
    if [[ "$TARGET_PATH" == *.wav ]]; then
        process_file "$TARGET_PATH"
    else
        echo -e "${RED}FEHLER: '$TARGET_PATH' ist keine WAV-Datei${NC}"
        exit 1
    fi
elif [ -d "$TARGET_PATH" ]; then
    # Verzeichnis mit mehreren Dateien
    file_count=0
    for wavfile in "$TARGET_PATH"/*.wav; do
        if [ -f "$wavfile" ]; then
            process_file "$wavfile"
            ((file_count++))
        fi
    done
    
    if [ $file_count -eq 0 ]; then
        echo -e "${RED}Keine WAV-Dateien in '$TARGET_PATH' gefunden.${NC}"
        exit 1
    fi
else
    echo -e "${RED}FEHLER: '$TARGET_PATH' existiert nicht${NC}"
    exit 1
fi

echo "=========================================="
echo "Alle Dateien verarbeitet!"
echo "=========================================="

