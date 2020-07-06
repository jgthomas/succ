#!/bin/bash

TESTS=$@

SUCC_BIN="succ-exe"
SUCC_BIN_PATH=$(stack exec which $SUCC_BIN)

TEST_DIR="$HOME/Code/succ-functional-tests"
TEST_SCRIPT="./test_compiler.sh"
ALL_TEST_CASES="literals \
                unary \
                3 \
                4 \
                5 \
                conditionals \
                compound \
                loops \
                functions \
                globals \
                ops \
                pointers \
                types \
                bitwise \
                array"


if [[ ! -z $TESTS ]]; then
        TEST_CASES=$TESTS
else
        TEST_CASES=$ALL_TEST_CASES
fi


(cd $TEST_DIR && $TEST_SCRIPT $SUCC_BIN_PATH $TEST_CASES)
