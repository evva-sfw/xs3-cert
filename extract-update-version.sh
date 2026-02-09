#!/bin/bash

# The --get-current-version command should be called before running release-it to update VERSION file with current version info
if [ "$1" == "--get-current-version" ]; then 
    CURRENT_VERSION=$(cat Sources/xs3-cert/version.swift | grep "static let version: String =" | sed -E 's/.*"([0-9]+\.[0-9]+\.[0-9]+)".*/\1/')
    echo VERSION=$CURRENT_VERSION > VERSION
    echo "Current version $CURRENT_VERSION placed in VERSION file for bumping"
fi;

# The --update-new-version command should be called after running release-it to update VERSION file with new bumper version info. 
# This version info will be used in the binary build
if [ "$1" == "--update-new-version" ]; then 
    NEW_VERSION=$(cat VERSION | grep "VERSION=" | sed -E 's/.*([0-9]+\.[0-9]+\.[0-9]+).*/\1/')
    sed -i -E "s/static let version: String = \"[0-9]+\.[0-9]+\.[0-9]+\";/static let version: String = \"$NEW_VERSION\";/g" Sources/xs3-cert/version.swift
    echo "version.swift file has been updated with new version $NEW_VERSION information..."
fi;