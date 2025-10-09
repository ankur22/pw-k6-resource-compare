#!/bin/bash

# k6 vs Playwright Resource Comparison Test Runner
# Usage: ./run-tests.sh [k6|playwright|both|both-parallel]

set -e

# Default configuration (can be overridden with environment variables)
PLAYWRIGHT_WORKERS=${PLAYWRIGHT_WORKERS:-1}
PLAYWRIGHT_REPEAT=${PLAYWRIGHT_REPEAT:-1}
K6_VUS=${K6_VUS:-1}
K6_ITERATIONS=${K6_ITERATIONS:-1}

COLOR_BLUE='\033[0;34m'
COLOR_GREEN='\033[0;32m'
COLOR_YELLOW='\033[1;33m'
COLOR_RED='\033[0;31m'
COLOR_RESET='\033[0m'

log_info() {
    echo -e "${COLOR_BLUE}[INFO]${COLOR_RESET} $1"
}

log_success() {
    echo -e "${COLOR_GREEN}[SUCCESS]${COLOR_RESET} $1"
}

log_warning() {
    echo -e "${COLOR_YELLOW}[WARNING]${COLOR_RESET} $1"
}

log_error() {
    echo -e "${COLOR_RED}[ERROR]${COLOR_RESET} $1"
}

# Check if docker compose is running
check_services() {
    log_info "Checking if services are running..."
    if ! docker compose ps | grep -q "Up"; then
        log_error "Services are not running. Please run: docker compose up -d"
        exit 1
    fi
    log_success "Services are running"
}

# Check if test scripts exist
check_test_scripts() {
    local test_type=$1
    
    if [ "$test_type" == "k6" ] || [ "$test_type" == "both" ]; then
        if [ ! -f "test-scripts/k6/test.js" ]; then
            log_error "k6 test script not found at test-scripts/k6/test.js"
            return 1
        fi
    fi
    
    if [ "$test_type" == "playwright" ] || [ "$test_type" == "both" ]; then
        if [ ! -f "test-scripts/playwright/test.spec.js" ]; then
            log_error "Playwright test script not found at test-scripts/playwright/test.spec.js"
            return 1
        fi
    fi
    
    return 0
}

# Run k6 browser test
run_k6_test() {
    log_info "Running k6 browser test..."
    echo ""
    
    start_time=$(date +%s)
    
    if docker compose exec -T k6-browser k6 run /test-scripts/k6/test.js; then
        end_time=$(date +%s)
        duration=$((end_time - start_time))
        log_success "k6 browser test completed in ${duration}s"
        return 0
    else
        log_error "k6 browser test failed"
        return 1
    fi
}

# Run Playwright test
run_playwright_test() {
    log_info "Running Playwright test..."
    log_info "Configuration: Workers=${PLAYWRIGHT_WORKERS}, Repeat=${PLAYWRIGHT_REPEAT}"
    echo ""
    
    start_time=$(date +%s)
    
    if docker compose exec -T playwright sh -c "cd /test-scripts/playwright && npx playwright test test.spec.js --workers=${PLAYWRIGHT_WORKERS} --repeat-each=${PLAYWRIGHT_REPEAT}"; then
        end_time=$(date +%s)
        duration=$((end_time - start_time))
        log_success "Playwright test completed in ${duration}s"
        return 0
    else
        log_error "Playwright test failed"
        return 1
    fi
}

# Run both tests sequentially
run_both_sequential() {
    log_info "Running tests sequentially..."
    echo ""
    
    run_k6_test
    k6_result=$?
    
    echo ""
    
    run_playwright_test
    playwright_result=$?
    
    echo ""
    if [ $k6_result -eq 0 ] && [ $playwright_result -eq 0 ]; then
        log_success "All tests completed successfully"
        return 0
    else
        log_error "Some tests failed"
        return 1
    fi
}

# Run both tests in parallel
run_both_parallel() {
    log_info "Running tests in parallel..."
    log_warning "Watch Grafana dashboard for side-by-side comparison: http://localhost:3001"
    echo ""
    
    # Run k6 in background
    (
        run_k6_test
        echo $? > /tmp/k6_result.txt
    ) &
    k6_pid=$!
    
    # Run Playwright in background
    (
        run_playwright_test
        echo $? > /tmp/playwright_result.txt
    ) &
    playwright_pid=$!
    
    # Wait for both
    wait $k6_pid
    wait $playwright_pid
    
    # Check results
    k6_result=$(cat /tmp/k6_result.txt 2>/dev/null || echo 1)
    playwright_result=$(cat /tmp/playwright_result.txt 2>/dev/null || echo 1)
    
    # Cleanup
    rm -f /tmp/k6_result.txt /tmp/playwright_result.txt
    
    echo ""
    if [ $k6_result -eq 0 ] && [ $playwright_result -eq 0 ]; then
        log_success "All tests completed successfully"
        return 0
    else
        log_error "Some tests failed"
        return 1
    fi
}

# Show usage
usage() {
    echo "Usage: $0 [k6|playwright|both|both-parallel]"
    echo ""
    echo "Options:"
    echo "  k6              Run k6 browser test only"
    echo "  playwright      Run Playwright test only"
    echo "  both            Run both tests sequentially (default)"
    echo "  both-parallel   Run both tests in parallel for side-by-side comparison"
    echo ""
    echo "Examples:"
    echo "  $0 k6"
    echo "  $0 playwright"
    echo "  $0 both"
    echo "  $0 both-parallel"
    exit 1
}

# Main
main() {
    local test_type=${1:-both}
    
    # Validate input
    case $test_type in
        k6|playwright|both|both-parallel)
            ;;
        -h|--help)
            usage
            ;;
        *)
            log_error "Invalid option: $test_type"
            usage
            ;;
    esac
    
    # Check services
    check_services
    
    # Check test scripts based on type
    local check_type=$test_type
    if [ "$check_type" == "both-parallel" ]; then
        check_type="both"
    fi
    
    if ! check_test_scripts "$check_type"; then
        exit 1
    fi
    
    log_info "Grafana dashboard: http://localhost:3001"
    log_info "Prometheus: http://localhost:9090"
    echo ""
    
    # Run tests based on type
    case $test_type in
        k6)
            run_k6_test
            exit $?
            ;;
        playwright)
            run_playwright_test
            exit $?
            ;;
        both)
            run_both_sequential
            exit $?
            ;;
        both-parallel)
            run_both_parallel
            exit $?
            ;;
    esac
}

main "$@"

