set -e

BASE=$(basename "${1}" .mp3)

AUDIO=tmp/"${BASE}".flac

BEAT=tmp/"${BASE}"_vamp_bbc-vamp-plugins_bbc-rhythm_onset.csv
INTENSITY=tmp/"${BASE}"_vamp_bbc-vamp-plugins_bbc-energy_rmsenergy.csv
CSV=tmp/"${BASE}".csv
FUNSCRIPT=out/"${BASE}".funscript

mkdir -p out
mkdir -p tmp

ffmpeg -i "$1" "${AUDIO}"

sonic-annotator -t onset.rdf -w csv --csv-force "${AUDIO}"

sonic-annotator -n -d vamp:bbc-vamp-plugins:bbc-energy:rmsenergy  -S mean --summary-only --segments-from "${BEAT}"  -w csv --csv-force "${AUDIO}"

read MAX <<< $(awk -F, '
BEGIN {
    max=0
}
{
    value = $4
    if ( value > max )
        max = value
}
END {
    print max
}
' "${INTENSITY}")

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

rm tmp/*
