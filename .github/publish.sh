#!/bin/bash

########################
 # Output directory
OUTPUT_DIR="_PUBLISH"
 # Release asset name (<releaseName>.tar.gz)
RELEASE_NAME="ChatAdditions_publish"
 # AMXModX version. Should be 1.9 or 1.10
AMXMODX="1.9"
########################

 # Default compiler directory
COMPILER_PATH=".compiler"

# If a compiler folder not found - create new one
if [ ! -d ${COMPILER_PATH} ]; then
  TEMPDIR="./.temp"

  # Download AMXModX with linux and windows amxxpc binaries
  mkdir ${TEMPDIR}
  AMXX_FILENAME=$(curl https://www.amxmodx.org/amxxdrop/${AMXMODX}/amxmodx-latest-base-linux)
  curl -s https://www.amxmodx.org/amxxdrop/${AMXMODX}/${AMXX_FILENAME} | tar -xz -C ${TEMPDIR}

  AMXX_FILENAME=$(curl https://www.amxmodx.org/amxxdrop/${AMXMODX}/amxmodx-latest-base-windows)
  curl https://www.amxmodx.org/amxxdrop/${AMXMODX}/${AMXX_FILENAME} -o amxmodx.zip
  unzip -o amxmodx.zip -d ${TEMPDIR}
  rm amxmodx.zip

  # Download ReAPI
  curl -OL https://github.com/s1lentq/reapi/releases/download/5.19.0.211/reapi_5.19.0.211-dev.zip
  unzip -o reapi_*-dev.zip -d ${TEMPDIR}
  rm reapi_*-dev.zip

  # Remove extra content which not used
  rm -rf ${TEMPDIR}/addons/amxmodx/scripting/testsuite/
  rm -rf ${TEMPDIR}/addons/amxmodx/scripting/*.sma
  rm -rf ${TEMPDIR}/addons/amxmodx/plugins/*.amxx

  # Move compiler (AMXX + ReAPI) to permanent folder
  mkdir -p ${COMPILER_PATH}
  mv -f ${TEMPDIR}/addons/amxmodx/scripting/* ${COMPILER_PATH}

  # Remove extra files
  rm -rf ${TEMPDIR}

  echo -e "\n=========================\n > Compiler ${AMXX_FILENAME} and ReAPI succefully downloaded!"
else
  echo -e "\n=========================\n > Compiler found at: ${COMPILER_PATH} path"
fi

AMXX_SCRIPTING_PATH=${COMPILER_PATH}
amxxpc="${AMXX_SCRIPTING_PATH}/amxxpc"

# Determinate win32 and use own compiler
case "$OSTYPE" in
  msys*)  amxxpc="${amxxpc}.exe" ;;
  *)      echo "unknown: $OSTYPE" ;;
esac

# Get full path for compiler file (not relative path)
function realpath {
  echo $(cd $(dirname $1); pwd)/$(basename $1);
}
amxxpc=$(realpath ${amxxpc})

# Create directory for plugins
rm -rf ${OUTPUT_DIR} && mkdir ${OUTPUT_DIR}
mkdir -p ${OUTPUT_DIR}/addons/amxmodx/plugins/

# Copy source files to compiler directory
scripting_dir=${OUTPUT_DIR}/addons/amxmodx/scripting
cp -rp cstrike/addons/amxmodx/*    ${OUTPUT_DIR}/addons/amxmodx/
# cp -rp extra/*           ${OUTPUT_DIR}

cd ${scripting_dir}
echo " > Current dir=${scripting_dir}"
echo " > amxxpc path=${amxxpc}"

# Compile plugins. Find any *.sma file and provide them to the compiler
find * -name "*.sma" \
  -exec echo -e "\n\n> Compile {} <" \;\
  -exec ${amxxpc} {} \
    -iinclude \
    -o../plugins/{} \
  \;

# Pack into one bundle for better release experience
cd ../../../
tar -czpf ${RELEASE_NAME}.tar.gz *
