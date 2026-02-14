#!/bin/bash
# Unit test runner

set -e

echo "============================================"
echo "  Running Unit Tests"
echo "============================================"
echo ""

# Add source directories to Lua path
export LUA_PATH="./?.lua;./spec/?.lua;./spec/unit/?.lua;./src/?.lua;;"

lua5.4 spec/unit/core_tests.lua

echo ""
echo "✓ All tests passed!"
