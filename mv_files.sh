#!/bin/bash

# Funktion zur Anzeige der Hilfe
show_help() {
    cat << 'EOF'
Verwendung:
  ./rename_ext.sh -from <ext1> -to <ext2>
  ./rename_ext.sh -?

Beschreibung:
  Benennt die Dateiendung aller passenden Dateien im AKTUELLEN VERZEICHNIS um.
  Es findet KEINE Unterordner-Durchsuchung und KEINE Inhalt-Konvertierung statt.

Parameter:
  -from <ext1>   Ausgangs-Dateiendung (z. B. wav oder .wav)
  -to <ext2>     Ziel-Dateiendung (z. B. mp3 oder .mp3)
  -?             Zeigt diese Hilfe an

Beispiele:
  ./rename_ext.sh -from wav -to mp3
  ./rename_ext.sh -from .txt -to .log
EOF
}

# Variablen initialisieren
FROM_EXT=""
TO_EXT=""

# Argumente parsen
while [[ $# -gt 0 ]]; do
    case "$1" in
        "-_")
            show_help
            exit 0
            ;;
        -\?)
            show_help
            exit 0
            ;;
        -help|--help)
            show_help
            exit 0
            ;;
        -from)
            FROM_EXT="$2"
            shift 2
            ;;
        -to)
            TO_EXT="$2"
            shift 2
            ;;
        *)
            echo "Fehler: Unbekannter Parameter '$1'"
            echo "Nutze './rename_ext.sh -?' für die Hilfe."
            exit 1
            ;;
    esac
done

# Prüfen, ob Pflichtparameter vorhanden sind
if [[ -z "$FROM_EXT" || -z "$TO_EXT" ]]; then
    echo "Fehler: Beide Parameter (-from und -to) werden benötigt."
    echo "Nutze './rename_ext.sh -?' für die Hilfe."
    exit 1
fi

# Führende Punkte entfernen, falls welche mitgegeben wurden
FROM_EXT="${FROM_EXT#.}"
TO_EXT="${TO_EXT#.}"

# Zähler für geänderte Dateien
count=0

# Nullglob aktivieren, damit *.ext1 nicht als Text interpretiert wird, falls keine Datei existiert
shopt -s nullglob

files=(*."$FROM_EXT")

if [[ ${#files[@]} -eq 0 ]]; then
    echo "Keine Dateien mit der Endung '.$FROM_EXT' im aktuellen Verzeichnis gefunden."
    exit 0
fi

for file in "${files[@]}"; do
    # Sicherstellen, dass es sich um eine reguläre Datei handelt
    if [[ -f "$file" ]]; then
        base_name="${file%."$FROM_EXT"}"
        new_name="${base_name}.${TO_EXT}"

        echo "Umbenennen: $file -> $new_name"
        mv -- "$file" "$new_name"
        ((count++))
    fi
done

echo "Fertig: $count Datei(en) umbenannt."
