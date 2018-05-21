#!/bin/bash
set -ev

# Write the short version into file and make a long version with the shorthash
SHORT_HASH=$(git rev-parse --short HEAD)  # also: TRAVIS_COMMIT
echo "Short hash: ${SHORT_HASH}"

# Take only the first string. Discards other strings
a=($(cat version.txt | xargs))
version_no=${a[0]}

BUILD_VERSION=${version_no}.${TRAVIS_BUILD_NUMBER}
echo "BUILD_VERSION: ${BUILD_VERSION}"
echo ${BUILD_VERSION} > version.txt

# Prepare version with githash (unused)
BUILD_VERSION=${BUILD_VERSION}-${SHORT_HASH}
echo "Could use the following for conda: $BUILD_VERSION"

echo "New version of 'version.txt': "
cat version.txt
