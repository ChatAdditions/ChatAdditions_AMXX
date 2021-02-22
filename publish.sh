#!/bin/bash          

########################
AMXX_SCRIPTING_PATH=""
OUTPUT_DIR="_PUBLISH"
RELEASE_NAME="ChatAdditions_publish"
AMXMODX="1.9"
########################
COMPILER_PATH=".compiler"

if [ ! -d ${COMPILER_PATH} ]; then
    TEMPDIR="./.temp"

    mkdir ${TEMPDIR}
    AMXX_FILENAME=$(curl https://www.amxmodx.org/amxxdrop/${AMXMODX}/amxmodx-latest-base-linux)
    curl -s https://www.amxmodx.org/amxxdrop/${AMXMODX}/${AMXX_FILENAME} | tar -xz -C ${TEMPDIR}

    AMXX_FILENAME=$(curl https://www.amxmodx.org/amxxdrop/${AMXMODX}/amxmodx-latest-base-windows)
    curl https://www.amxmodx.org/amxxdrop/${AMXMODX}/${AMXX_FILENAME} -o amxmodx.zip
    unzip -o amxmodx.zip -d ${TEMPDIR}
    rm amxmodx.zip

    curl -OL https://github.com/s1lentq/reapi/releases/download/5.19.0.211/reapi_5.19.0.211-dev.zip
    unzip -o reapi_*-dev.zip -d ${TEMPDIR}
    rm reapi_*-dev.zip

    rm -rf ${TEMPDIR}/addons/amxmodx/scripting/testsuite/
    rm -rf ${TEMPDIR}/addons/amxmodx/scripting/*.sma
    rm -rf ${TEMPDIR}/addons/amxmodx/plugins/*.amxx

    mkdir -p ${COMPILER_PATH}
    mv -f ${TEMPDIR}/addons/amxmodx/scripting/* ${COMPILER_PATH}

    rm -rf ${TEMPDIR}

    echo -e "\n=========================\n > Compiler ${AMXX_FILENAME} and ReAPI succefully downloaded!"
else
    echo -e "\n=========================\n > Compiler found at: ${COMPILER_PATH} path"
fi

AMXX_SCRIPTING_PATH=${COMPILER_PATH}
amxxpc="${AMXX_SCRIPTING_PATH}/amxxpc"

case "$OSTYPE" in
  msys*)    amxxpc="${amxxpc}.exe" ;;
  *)        echo "unknown: $OSTYPE" ;;
esac

function realpath {
    echo $(cd $(dirname $1); pwd)/$(basename $1);
}
amxxpc=$(realpath ${amxxpc})

# Create dir
rm -rf ${OUTPUT_DIR} && mkdir ${OUTPUT_DIR}
mkdir -p ${OUTPUT_DIR}/addons/amxmodx/plugins/

scripting_dir=${OUTPUT_DIR}/addons/amxmodx/scripting
cp -rp cstrike/addons/amxmodx/*    ${OUTPUT_DIR}/addons/amxmodx/
cp -rp cstrike/addons/amxmodx/scripting/    ${scripting_dir}
# cp -rp extra/*           ${OUTPUT_DIR}

# Compile
cd ${scripting_dir}
echo " > Current dir=${scripting_dir}"
echo " > amxxpc path=${amxxpc}"

find * -name "*.sma" \
    -exec echo -e "\n\n> Compile {} <" \;\
    -exec ${amxxpc} {} \
        -iinclude \
        -o../plugins/{} \
    \;

# Pack to release
cd ../../../
tar -czpf ${RELEASE_NAME}.tar.gz *
