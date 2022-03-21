set -e

BASE=$(basename "${1}" .mp3)

AUDIO=tmp/"${BASE}".flac

BEAT=tmp/"${BASE}"_vamp_bbc-vamp-plugins_bbc-rhythm_onset.csv
ENERGY=tmp/"${BASE}"_vamp_bbc-vamp-plugins_bbc-energy_rmsenergy.csv
PITCH=tmp/"${BASE}"_vamp_vamp-aubio_aubiopitch_frequency.csv
CSV=tmp/"${BASE}".csv
FUNSCRIPT=out/"${BASE}".funscript

mkdir -p out
mkdir -p tmp

ffmpeg -i "$1" "${AUDIO}"

sonic-annotator -t onset.rdf -w csv --csv-force "${AUDIO}"

sonic-annotator -n -d vamp:bbc-vamp-plugins:bbc-energy:rmsenergy -d vamp:vamp-aubio:aubiopitch:frequency -S mean --summary-only --segments-from "${BEAT}"  -w csv --csv-force "${AUDIO}"

read MIN_ENERGY MAX_ENERGY <<< $(awk -F, '
BEGIN {
    max=0
    min=10000
}
{
    value = $4
    if ( value > max )
        max = value
    if ( value < min )
        min = value
}
END {
    print min,max
}
' "${ENERGY}")

exec awk -F, -v max="${MAX_ENERGY}" '
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
' "${ENERGY}" > "${FUNSCRIPT}"

rm tmp/*
