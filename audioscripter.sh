set -e

OFFSET_RANGE=100
MULTIPLIER=1.2
THRESHOLD=0.3

BASE=$(basename "${1}" .mp4)

AUDIO=tmp/"${BASE}".wav

BEAT=tmp/"${BASE}"_vamp_bbc-vamp-plugins_bbc-rhythm_onset.csv
ENERGY=tmp/"${BASE}"_vamp_bbc-vamp-plugins_bbc-energy_rmsenergy.csv
PITCH=tmp/"${BASE}"_vamp_vamp-aubio_aubiopitch_frequency.csv
OFFSET=tmp/"${BASE}"_offset.csv
CSV=tmp/"${BASE}".csv
FUNSCRIPT=out/"${BASE}".funscript

mkdir -p out tmp

if [ ! -f "${AUDIO}" ]
then
    ffmpeg -i "$1" -vn "${AUDIO}"
fi

sed "s/THRESHOLD/${THRESHOLD}/g" onset.rdf > tmp/onset.rdf

sonic-annotator -t tmp/onset.rdf -w csv --csv-force "${AUDIO}"

sonic-annotator -n -d vamp:bbc-vamp-plugins:bbc-energy:rmsenergy -d vamp:vamp-aubio:aubiopitch:frequency -S mean --summary-only --segments-from "${BEAT}"  -w csv --csv-force "${AUDIO}"

read MIN_PITCH MAX_PITCH <<< $(awk -f minmax.awk "${PITCH}")

awk -v max="${MAX_PITCH}" -v min="${MIN_PITCH}" -v range="${OFFSET_RANGE}" -f offsets.awk "${PITCH}" > "${OFFSET}"

echo "Min pitch: ${MIN_PITCH} Max pitch: ${MAX_PITCH}"

read MIN_ENERGY MAX_ENERGY <<< $(awk -f minmax.awk "${ENERGY}")

echo "Min energy: ${MIN_ENERGY} Max energy: ${MAX_ENERGY}"

awk -v max="${MAX_ENERGY}" -v min="${MIN_ENERGY}" -v multiplier="${MULTIPLIER}" -f funscript.awk "${OFFSET}" "${ENERGY}" > "${FUNSCRIPT}" 2>debug

echo "Written ${FUNSCRIPT}"

rm -rf tmp
