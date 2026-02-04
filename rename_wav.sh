#!/bin/bash

# Konfiguration
QUELLE_VERZEICHNIS="."
NAMEN_VERZEICHNIS=""
BACKUP_VERZEICHNIS="./BACKUP"

# Farben für Ausgabe
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Funktion für Hilfetext
show_help() {
    echo "Verwendung: $0 -n <namen_verzeichnis>"
    echo ""
    echo "Optionen:"
    echo "  -n    Pfad zum Verzeichnis mit den neuen Dateinamen (relativ oder absolut)"
    echo "  -h    Zeigt diese Hilfe an"
    echo ""
    echo "Beispiel:"
    echo "  $0 -n ../neue_namen"
    echo "  $0 -n ./referenz_dateien"
    exit 1
}

# Parse Kommandozeilen-Argumente
while getopts "n:h" opt; do
    case $opt in
        n)
            NAMEN_VERZEICHNIS="$OPTARG"
            ;;
        h)
            show_help
            ;;
        \?)
            echo -e "${RED}Ungültige Option: -$OPTARG${NC}" >&2
            show_help
            ;;
    esac
done

# Prüfe ob -n Parameter angegeben wurde
if [ -z "$NAMEN_VERZEICHNIS" ]; then
    echo -e "${RED}Fehler: Parameter -n muss angegeben werden${NC}"
    echo ""
    show_help
fi

# Prüfe ob Namen-Verzeichnis existiert
if [ ! -d "$NAMEN_VERZEICHNIS" ]; then
    echo -e "${RED}Fehler: Verzeichnis '$NAMEN_VERZEICHNIS' existiert nicht${NC}"
    exit 1
fi

# Backup-Verzeichnis erstellen, falls nicht vorhanden
if [ ! -d "$BACKUP_VERZEICHNIS" ]; then
    echo -e "${YELLOW}Erstelle Backup-Verzeichnis: $BACKUP_VERZEICHNIS${NC}"
    mkdir -p "$BACKUP_VERZEICHNIS"
fi

# Zähler für Statistik
renamed_count=0
not_found_count=0

echo "=== Starte Umbenennung von WAV-Dateien ==="
echo "Namen-Verzeichnis: $NAMEN_VERZEICHNIS"
echo ""

# Durchlaufe alle .wav Dateien im aktuellen Verzeichnis
for datei in "$QUELLE_VERZEICHNIS"/*.wav; do
    # Prüfe ob Dateien existieren
    if [ ! -f "$datei" ]; then
        echo -e "${RED}Keine .wav Dateien gefunden${NC}"
        exit 1
    fi
    
    # Extrahiere Dateinamen ohne Pfad
    dateiname=$(basename "$datei")
    
    # Extrahiere die ersten 3 Zeichen (die Nummer)
    nummer="${dateiname:0:3}"
    
    # Prüfe ob es sich um eine 3-stellige Zahl handelt
    if ! [[ "$nummer" =~ ^[0-9]{3}$ ]]; then
        echo -e "${YELLOW}Überspringe: $dateiname (beginnt nicht mit 3-stelliger Zahl)${NC}"
        continue
    fi
    
    # Suche nach passender Datei im Namen-Verzeichnis
    gefundene_datei=$(find "$NAMEN_VERZEICHNIS" -maxdepth 1 -type f -name "${nummer}*" | head -n 1)
    
    if [ -z "$gefundene_datei" ]; then
        echo -e "${RED}✗ Keine passende Datei für $dateiname (Nummer: $nummer) gefunden${NC}"
        ((not_found_count++))
        continue
    fi
    
    # Extrahiere neuen Dateinamen
    neuer_name=$(basename "$gefundene_datei")
    
    # Erstelle Backup
    echo -e "${YELLOW}Erstelle Backup: $dateiname → $BACKUP_VERZEICHNIS/$dateiname${NC}"
    cp "$datei" "$BACKUP_VERZEICHNIS/$dateiname"
    
    # Benenne Datei um
    mv "$datei" "$QUELLE_VERZEICHNIS/$neuer_name"
    echo -e "${GREEN}✓ Umbenannt: $dateiname → $neuer_name${NC}"
    ((renamed_count++))
    echo ""
done

# Statistik ausgeben
echo "=== Zusammenfassung ==="
echo -e "${GREEN}Erfolgreich umbenannt: $renamed_count${NC}"
echo -e "${RED}Nicht gefunden: $not_found_count${NC}"

