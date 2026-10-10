#!/bin/bash

export LC_ALL=C
export LC_NUMERIC=C

RED=$'\033[31m'
GREEN=$'\033[32m'
BLUE=$'\033[34m'
RESET=$'\033[0m'

START_LIMIT=0.5
END_LIMIT=0.5
TOLERANCE=10
LEVEL_DB=-50
DO_FIX=0

FILES=()

###############################################
# PARAMETER EINLESEN
###############################################
while [[ $# -gt 0 ]]; do
    case "$1" in
        -s) START_LIMIT="$2"; shift 2 ;;
        -e) END_LIMIT="$2"; shift 2 ;;
        -t) TOLERANCE="$2"; shift 2 ;;
        -l) LEVEL_DB="$2"; shift 2 ;;
        -fix) DO_FIX=1; shift ;;
        *) FILES+=("$1"); shift ;;
    esac
done

if [[ ${#FILES[@]} -eq 0 ]]; then
    FILES=( *.wav )
fi

###############################################
# STILLE MESSEN
###############################################
measure_silence() {
    local file="$1"

    local total
    total=$(ffprobe -v error -show_entries format=duration \
            -of default=noprint_wrappers=1:nokey=1 "$file")

    local output
    output=$(ffmpeg -i "$file" -af silencedetect=noise=${LEVEL_DB}dB:d=0.05 -f null - 2>&1)

    local leading=0
    local trailing=0

    while IFS= read -r line; do
        local end dur start

        end=$(echo "$line" | awk -F'silence_end: ' '{print $2}' | awk '{print $1}')
        dur=$(echo "$line" | awk -F'silence_duration: ' '{print $2}' | awk '{print $1}')
        start=$(awk -v e="$end" -v d="$dur" 'BEGIN { printf "%.6f", e - d }')

        if awk -v s="$start" 'BEGIN { exit !(s <= 0.05) }'; then
            leading="$dur"
        fi

        if awk -v e="$end" -v T="$total" 'BEGIN { exit !(e >= T - 0.05) }'; then
            trailing="$dur"
        fi
    done < <(echo "$output" | grep "silence_end:")

    echo "$leading" "$trailing"
}

###############################################
# TOLERANZPRÜFUNG
###############################################
check_tolerance() {
    local measured="$1"
    local limit="$2"
    local tol="$3"

    local lower=$(echo "$limit * (1 - $tol/100)" | bc -l)
    local upper=$(echo "$limit * (1 + $tol/100)" | bc -l)

    awk -v m="$measured" -v lo="$lower" -v up="$upper" '
        BEGIN { if (m < lo || m > up) print "BAD"; else print "OK"; }
    '
}

###############################################
# DAUER ERMITTELN
###############################################
get_duration() {
    ffprobe -v error -show_entries format=duration \
        -of default=noprint_wrappers=1:nokey=1 "$1"
}

###############################################
# ECHTE STILLE EXTRAHIEREN
###############################################
extract_real_silence() {
    local file="$1"
    local dur="$2"

    ffmpeg -y -i "$file" -ss 0 -t "$dur" -c:a pcm_s16le real_silence.wav >/dev/null 2>&1
}

###############################################
# HAUPTSCHLEIFE
###############################################
for f in "${FILES[@]}"; do

    log="${f%.*}.log"
    echo "Analyse von $f" > "$log"
    echo "----------------------------------------" >> "$log"

    read start end < <(measure_silence "$f")

    start=$(printf "%.3f" "$start")
    end=$(printf "%.3f" "$end")

    status_start=$(check_tolerance "$start" "$START_LIMIT" "$TOLERANCE")
    status_end=$(check_tolerance "$end" "$END_LIMIT" "$TOLERANCE")

    dev_start=$(awk -v m="$start" -v s="$START_LIMIT" 'BEGIN { printf "%.1f", ((m-s)/s)*100 }')
    dev_end=$(awk -v m="$end" -v s="$END_LIMIT" 'BEGIN { printf "%.1f", ((m-s)/s)*100 }')

    color_dev_start="$RESET"
    color_dev_end="$RESET"

    if (( $(echo "$dev_start > 0" | bc -l) )); then color_dev_start="$RED"
    elif (( $(echo "$dev_start < 0" | bc -l) )); then color_dev_start="$BLUE"; fi

    if (( $(echo "$dev_end > 0" | bc -l) )); then color_dev_end="$RED"
    elif (( $(echo "$dev_end < 0" | bc -l) )); then color_dev_end="$BLUE"; fi

    ###############################################
    # KORREKTUR
    ###############################################
    if [[ $DO_FIX -eq 1 ]]; then

        if [[ "$status_start" == "BAD" || "$status_end" == "BAD" ]]; then
            out="${f%.*}_corrected.wav"
            cp "$f" "$out"
            echo "Korrekturdatei: $out" >> "$log"
        else
            out=""
        fi

        if [[ -n "$out" ]]; then

            ################################
            # START-KORREKTUR
            ################################
            if [[ "$status_start" == "BAD" ]]; then
                if (( $(echo "$start > $START_LIMIT" | bc -l) )); then
                    cut=$(echo "$start - $START_LIMIT" | bc -l)
                    ffmpeg -y -i "$out" -ss "$cut" -c:a pcm_s16le tmp.wav >/dev/null 2>&1
                    [[ -f tmp.wav ]] && mv tmp.wav "$out"
                else
                    needed=$(echo "$START_LIMIT - $start" | bc -l)
                    extract_real_silence "$f" "$start"
                    reps=$(awk -v n="$needed" -v s="$start" 'BEGIN { printf "%d", (n/s)+1 }')
                    ffmpeg -y -stream_loop $((reps-1)) -i real_silence.wav -t "$needed" -c:a pcm_s16le pad.wav >/dev/null 2>&1
                    ffmpeg -y -i pad.wav -i "$out" -filter_complex "[0:a][1:a]concat=n=2:v=0:a=1" -c:a pcm_s16le tmp.wav >/dev/null 2>&1
                    [[ -f tmp.wav ]] && mv tmp.wav "$out"
                fi
            fi

            ################################
            # ENDE-KORREKTUR
            ################################
            if [[ "$status_end" == "BAD" ]]; then
                if (( $(echo "$end > $END_LIMIT" | bc -l) )); then
                    dur=$(get_duration "$out")
                    newdur=$(echo "$dur - ($end - $END_LIMIT)" | bc -l)
                    ffmpeg -y -i "$out" -t "$newdur" -c:a pcm_s16le tmp.wav >/dev/null 2>&1
                    [[ -f tmp.wav ]] && mv tmp.wav "$out"
                else
                    needed=$(echo "$END_LIMIT - $end" | bc -l)
                    extract_real_silence "$f" "$end"
                    reps=$(awk -v n="$needed" -v s="$end" 'BEGIN { printf "%d", (n/s)+1 }')
                    ffmpeg -y -stream_loop $((reps-1)) -i real_silence.wav -t "$needed" -c:a pcm_s16le pad.wav >/dev/null 2>&1
                    ffmpeg -y -i "$out" -i pad.wav -filter_complex "[0:a][1:a]concat=n=2:v=0:a=1" -c:a pcm_s16le tmp.wav >/dev/null 2>&1
                    [[ -f tmp.wav ]] && mv tmp.wav "$out"
                fi
            fi

            rm -f real_silence.wav pad.wav 2>/dev/null
        fi
    fi

    if [[ "$status_start" == "OK" && "$status_end" == "OK" ]]; then
        line_color="$GREEN"
    else
        line_color="$RESET"
    fi

    printf "%s%-30s  Start: %.2fs (%s%+5.1f%%%s)  Ende: %.2fs (%s%+5.1f%%%s)  (Level: %sdB)%s\n" \
        "$line_color" "$f" \
        "$start" "$color_dev_start" "$dev_start" "$RESET" \
        "$end"   "$color_dev_end"   "$dev_end"   "$RESET" \
        "$LEVEL_DB" "$RESET"

done

