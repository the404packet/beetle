#!/usr/bin/env bash

# ==============================================================================
# Beetle Test Library: Common Assertions and Test Formatting
# ==============================================================================

COLOR_RESET="\033[0m"
COLOR_GREEN="\033[32m"
COLOR_RED="\033[31m"
COLOR_YELLOW="\033[33m"
COLOR_BLUE="\033[34m"
COLOR_CYAN="\033[36m"

TESTS_PASSED=0
TESTS_FAILED=0

log_section() {
    echo -e "\n${COLOR_CYAN}======================================================================${COLOR_RESET}"
    echo -e "${COLOR_CYAN}  $1${COLOR_RESET}"
    echo -e "${COLOR_CYAN}======================================================================${COLOR_RESET}"
}

log_step() {
    echo -e "${COLOR_BLUE}[STEP]${COLOR_RESET} $1"
}

log_success() {
    echo -e "${COLOR_GREEN}[SUCCESS]${COLOR_RESET} $1"
}

log_failure() {
    echo -e "${COLOR_RED}[FAILURE]${COLOR_RESET} $1"
}

log_warn() {
    echo -e "${COLOR_YELLOW}[WARN]${COLOR_RESET} $1"
}

# Assert that an audit output contains "NOT HARDENED" or fails
assert_audit_unhardened() {
    local output="$1"
    local test_name="$2"

    if echo "$output" | grep -q "NOT HARDENED"; then
        log_success "PASS: $test_name (Correctly flagged as NOT HARDENED)"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        log_failure "FAIL: $test_name (Expected NOT HARDENED, but got HARDENED)"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

# Assert that an audit output contains "HARDENED" and no "NOT HARDENED"
assert_audit_hardened() {
    local output="$1"
    local test_name="$2"

    if echo "$output" | grep -q "HARDENED" && ! echo "$output" | grep -q "NOT HARDENED"; then
        log_success "PASS: $test_name (Verified HARDENED)"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        log_failure "FAIL: $test_name (Expected HARDENED, but unhardened checks remain)"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

print_summary() {
    echo -e "\n${COLOR_CYAN}----------------------------------------------------------------------${COLOR_RESET}"
    echo -e "Test Results: ${COLOR_GREEN}${TESTS_PASSED} Passed${COLOR_RESET}, ${COLOR_RED}${TESTS_FAILED} Failed${COLOR_RESET}"
    echo -e "${COLOR_CYAN}----------------------------------------------------------------------${COLOR_RESET}"
    if [ "$TESTS_FAILED" -ne 0 ]; then
        exit 1
    fi
}
