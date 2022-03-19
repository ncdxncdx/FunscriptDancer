set -e

INPUT="$1"
BASE="${INPUT%.*}"
BEAT="${BASE}"_vamp_beatroot-vamp_beatroot_beats.csv
INTENSITY="${BASE}"_vamp_bbc-vamp-plugins_bbc-intensity_intensity.csv
CSV="${BASE}".csv
FUNSCRIPT="${BASE}".funscript

sonic-annotator -d vamp:beatroot-vamp:beatroot:beats -w csv --csv-force "${INPUT}"

sonic-annotator -n -d vamp:bbc-vamp-plugins:bbc-intensity:intensity  -S mean --summary-only --segments-from "${BEAT}"  -w csv --csv-force "${INPUT}"

MAX=$(cut -d, -f4 < "${INTENSITY}" | sort -nr | head -1)

exec awk -F, -v max="${MAX}" '
BEGIN { direction = 1; print "{ \"actions\": [" }
{
    value = $4
    at = int( $1 * 1000 )
    norm = value * 50 * direction / max
    pos = int( 50 + norm )
    direction = direction * -1
    printf "%s{\"pos\": \"%s\", \"at\": \"%s\"}", separator, pos, at
    separator = ","
}
END { print " ] } " }
' "${INTENSITY}" > "${FUNSCRIPT}"
