set -e

export OFFSET_RANGE=100
export MULTIPLIER=1.5

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
FUNSCRIPT_TMP=tmp/"${BASE}".funscript
FUNSCRIPT=out/"${BASE}".funscript

mkdir -p out tmp

DURATION_S=$(ffprobe -i "${1}" -show_entries format=duration -v quiet -of csv="p=0")
export DURATION=$(echo "${DURATION_S}" | cut -f1 -d ".")

if [ ! -f "${BEAT}" ] || [ ! -f "${ENERGY}" ] || [ ! -f "${PITCH}" ] 
then
    if [ ! -f "${AUDIO}" ]
    then
        ffmpeg -i "$1" -vn "${AUDIO}"
    fi
    
    if [ ! -f "${BEAT}" ]
    then
        sonic-annotator -d "${BEAT_TRANSFORM}" -w csv --csv-force "${AUDIO}"
    fi
    if [ ! -f "${ENERGY}" ]
    then
        sonic-annotator -d "${ENERGY_TRANSFORM}" -S sum --summary-only --segments-from "${BEAT}"  -w csv --csv-force "${AUDIO}" &
    fi
    if [ ! -f "${PITCH}" ]
    then
        sonic-annotator -d "${PITCH_TRANSFORM}" -S mean --summary-only --segments-from "${BEAT}"  -w csv --csv-force "${AUDIO}" &
    fi
    wait
fi

rm -f "${AUDIO}"

read MIN_PITCH MAX_PITCH <<< $(awk -f minmax.awk "${PITCH}")

awk -v max="${MAX_PITCH}" -v min="${MIN_PITCH}" -v range="${OFFSET_RANGE}" -f offsets.awk "${PITCH}" > "${OFFSET}"

echo "Min pitch: ${MIN_PITCH} Max pitch: ${MAX_PITCH}" >> "${DEBUG}"

read MIN_ENERGY MAX_ENERGY <<< $(awk -f minmax.awk "${ENERGY}")

echo "Min energy: ${MIN_ENERGY} Max energy: ${MAX_ENERGY}" >> "${DEBUG}"

awk -v max="${MAX_ENERGY}" -v min="${MIN_ENERGY}" -v multiplier="${MULTIPLIER}" -f funscript.awk "${OFFSET}" "${ENERGY}" > "${ACTIONS}" 2>>"${DEBUG}"

envsubst < template.funscript.json > "${FUNSCRIPT_TMP}"

sed -i -e "/actions/r./${ACTIONS}" "${FUNSCRIPT_TMP}"

jq -c . "${FUNSCRIPT_TMP}" > "${FUNSCRIPT}"

echo "Written ${FUNSCRIPT}"
