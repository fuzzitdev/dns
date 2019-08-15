#!/bin/bash
set -xe

# fuzz only in one configuration
# there's no benefit to fuzzing with different go versions
if [ -z ${WITH_FUZZ} ]; then
    exit 0
fi

# go-fuzz doesn't support modules yet, so ensure we do everything
# in the old style GOPATH way
export GO111MODULE="off"

# install go-fuzz
go get -u github.com/dvyukov/go-fuzz/go-fuzz github.com/dvyukov/go-fuzz/go-fuzz-build

# target name can only contain lower-case letters (a-z), digits (0-9) and a dash (-)
# to add another target, make sure to create it with `fuzzit create target`
# before using `fuzzit create job`
TARGETS=("dns-fuzz" "dns-fuzz-rr")

go-fuzz-build -tags fuzz -libfuzzer -func Fuzz -o dns-fuzz.a github.com/miekg/dns
go-fuzz-build -tags fuzz -libfuzzer -func FuzzNewRR -o dns-fuzz-rr.a github.com/miekg/dns

for TARGET in "${TARGETS[@]}"
do
    clang -fsanitize=fuzzer ${TARGET}.a -o ${TARGET}
done

# install fuzzit for talking to fuzzit.dev service
# or latest version:
# https://github.com/fuzzitdev/fuzzit/releases/latest/download/fuzzit_Linux_x86_64
wget -q -O fuzzit https://github.com/fuzzitdev/fuzzit/releases/download/v2.4.24/fuzzit_Linux_x86_64
chmod a+x fuzzit

# upload fuzz target for long fuzz testing on fuzzit.dev server 
# or run locally for regression, depending on --type
if [ "${TRAVIS_PULL_REQUEST}" == "false" ]; then
	TYPE=fuzzing
else
	TYPE=local-regression
fi

# upload fuzz target for long fuzz testing on fuzzit.dev server 
# or run locally for regression, depending on --type
for TARGET in "${TARGETS[@]}"
do
    ./fuzzit create job --type ${TYPE} kkowalczyk/${TARGET} ${TARGET}
done