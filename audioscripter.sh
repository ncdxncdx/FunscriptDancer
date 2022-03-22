set -e

export OFFSET_RANGE=100
export MULTIPLIER=1
export THRESHOLD=0.3

export BASE=$(basename "${1}" .mp4)

AUDIO=tmp/"${BASE}".wav

BEAT=tmp/"${BASE}"_vamp_bbc-vamp-plugins_bbc-rhythm_onset.csv
ENERGY=tmp/"${BASE}"_vamp_bbc-vamp-plugins_bbc-energy_rmsenergy.csv
PITCH=tmp/"${BASE}"_vamp_vamp-aubio_aubiopitch_frequency.csv
OFFSET=tmp/"${BASE}"_offset.csv
CSV=tmp/"${BASE}".csv
FUNSCRIPT=out/"${BASE}".funscript

mkdir -p out tmp
rm -f debug

if [ ! -f "${AUDIO}" ]
then
    ffmpeg -i "$1" -vn "${AUDIO}"
fi

envsubst < onset.rdf > tmp/onset.rdf

sonic-annotator -t tmp/onset.rdf -w csv --csv-force "${AUDIO}"

if [ ! -f "${ENERGY}" ]
then
    sonic-annotator -n -d vamp:bbc-vamp-plugins:bbc-energy:rmsenergy -S sum --summary-only --segments-from "${BEAT}"  -w csv --csv-force "${AUDIO}"
fi

if [ ! -f "${PITCH}" ]
then
    sonic-annotator -n -d vamp:vamp-aubio:aubiopitch:frequency -S mean --summary-only --segments-from "${BEAT}"  -w csv --csv-force "${AUDIO}"
fi

read MIN_PITCH MAX_PITCH <<< $(awk -f minmax.awk "${PITCH}")

awk -v max="${MAX_PITCH}" -v min="${MIN_PITCH}" -v range="${OFFSET_RANGE}" -f offsets.awk "${PITCH}" > "${OFFSET}"

echo "Min pitch: ${MIN_PITCH} Max pitch: ${MAX_PITCH}" >> debug

read MIN_ENERGY MAX_ENERGY <<< $(awk -f minmax.awk "${ENERGY}")

echo "Min energy: ${MIN_ENERGY} Max energy: ${MAX_ENERGY}" >> debug

export ACTIONS=$(awk -v max="${MAX_ENERGY}" -v min="${MIN_ENERGY}" -v multiplier="${MULTIPLIER}" -f funscript.awk "${OFFSET}" "${ENERGY}" 2>>debug)

echo "${ACTIONS}" >> debug

envsubst < template.funscript.json > "${FUNSCRIPT}"

echo "Written ${FUNSCRIPT}"

# rm -rf tmp
