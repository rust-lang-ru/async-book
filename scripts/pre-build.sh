#!/bin/bash

set -eu

SCRIPTS_DIR="`dirname ${0}`"
ROOT="`realpath ${SCRIPTS_DIR}/../`"
pushd $ROOT
rsync -arvh async-book/examples async-book-ru/
popd
#
