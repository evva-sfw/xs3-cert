#!/bin/zsh
LOCAL_BINARY=./.build/aarch64-swift-linux-musl/debug/xs3-cert
BINDIR=$(pwd)/dist 
OUTDIR=$(pwd)/out
mkdir -p $OUTDIR
mkdir -p $BINDIR
cp $LOCAL_BINARY $BINDIR
container run --rm -v $BINDIR:/mybin -v ${OUTDIR}:/out --entrypoint=/mybin/xs3-cert cgr.dev/chainguard/static:latest $*

