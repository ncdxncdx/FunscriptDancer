set -e

export OFFSET_RANGE=100
export MULTIPLIER=1
export THRESHOLD=0.3

export BASE=$(basename "${1}" .mp4)

export BEAT_TRANSFORM=vamp:vamp-aubio:aubiotempo:beats
export ENERGY_TRANSFORM=vamp:bbc-vamp-plugins:bbc-energy:rmsenergy
export PITCH_TRANSFORM=vamp:vamp-aubio:aubiopitch:frequency

AUDIO=tmp/"${BASE}".wav
BEAT=tmp/"${BASE}"_"$(sed "s/:/_/g" <<< ${BEAT_TRANSFORM})".csv
ENERGY=tmp/"${BASE}"_"$(sed "s/:/_/g" <<< ${ENERGY_TRANSFORM})".csv
PITCH=tmp/"${BASE}"_"$(sed "s/:/_/g" <<< ${PITCH_TRANSFORM})".csv
OFFSET=tmp/"${BASE}"_offset.csv
ACTIONS=tmp/"${BASE}"_actions.csv
PIPE=tmp/"${BASE}"_pipe
DEBUG=tmp/"${BASE}"_debug
FUNSCRIPT=out/"${BASE}".funscript

rm -rf tmp
mkdir -p out tmp

if [ ! -f "${AUDIO}" ]
then
    ffmpeg -i "$1" -vn "${AUDIO}"
fi
DURATION_S=$(ffprobe -i "${AUDIO}" -show_entries format=duration -v quiet -of csv="p=0")
export DURATION=$(echo "${DURATION_S} * 1000" | bc | cut -f1 -d ".")

envsubst < onset.rdf > tmp/onset.rdf

sonic-annotator -d "${BEAT_TRANSFORM}" -w csv --csv-force "${AUDIO}"
sonic-annotator -n -d "${ENERGY_TRANSFORM}" -S sum --summary-only --segments-from "${BEAT}"  -w csv --csv-force "${AUDIO}"
sonic-annotator -n -d "${PITCH_TRANSFORM}" -S mean --summary-only --segments-from "${BEAT}"  -w csv --csv-force "${AUDIO}"

read MIN_PITCH MAX_PITCH <<< $(awk -f minmax.awk "${PITCH}")

awk -v max="${MAX_PITCH}" -v min="${MIN_PITCH}" -v range="${OFFSET_RANGE}" -f offsets.awk "${PITCH}" > "${OFFSET}"

echo "Min pitch: ${MIN_PITCH} Max pitch: ${MAX_PITCH}" >> "${DEBUG}"

read MIN_ENERGY MAX_ENERGY <<< $(awk -f minmax.awk "${ENERGY}")

echo "Min energy: ${MIN_ENERGY} Max energy: ${MAX_ENERGY}" >> "${DEBUG}"

awk -v max="${MAX_ENERGY}" -v min="${MIN_ENERGY}" -v multiplier="${MULTIPLIER}" -f funscript.awk "${OFFSET}" "${ENERGY}" > "${ACTIONS}" 2>"${DEBUG}"

envsubst < template.funscript.json > "${FUNSCRIPT}"

sed -i -e "/actions/r./"${ACTIONS}"" "${FUNSCRIPT}"

echo "Written ${FUNSCRIPT}"
