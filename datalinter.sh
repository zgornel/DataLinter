#/bin/bash
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
CSV_FILE=$1

if [ -z "$1" ]; then
    echo "First argument i.e. csv file doesn’t exist or is empty."
    exit
fi

echo "Running data Linter in ${SCRIPT_DIR} on $CSV_FILE"
time docker run -it --rm --volume="${SCRIPT_DIR}":/tmp ghcr.io/zgornel/datalinter-compiled:latest /datalinter/bin/datalinter "/tmp/${CSV_FILE}" --print-exceptions --log-level debug
