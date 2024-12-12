#/bin/bash
INPUT_ARG=$1
DIR="${INPUT_ARG%/*}"
FILE="${INPUT_ARG##*/}"

if [ -z "$1" ]; then
    echo "First argument i.e. csv file doesn’t exist or is empty."
    exit
fi

docker run -it --rm \
    --volume="${DIR}":/tmp ghcr.io/zgornel/datalinter-compiled:latest \
        /datalinter/bin/datalinter \
            "/tmp/${FILE}" \
            --progress \
            --timed \
            --print-exceptions \
            --log-level error
