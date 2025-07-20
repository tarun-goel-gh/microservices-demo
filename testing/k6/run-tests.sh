#!/bin/bash

# K6 Performance Testing Script for Microservices Demo
# This script provides various options to run performance tests

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
BASE_URL="http://localhost:8080"
TEST_TYPE="load_test"
OUTPUT_FORMAT="json"
RESULTS_DIR="./results"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

# Function to print colored output
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to show usage
show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -u, --url BASE_URL        Base URL for the application (default: http://localhost:8080)"
    echo "  -t, --test TEST_TYPE      Test type: smoke, load, stress, spike, endurance, catalog, cart, comprehensive (default: load)"
    echo "  -o, --output FORMAT       Output format: json, influxdb, cloudwatch, datadog (default: json)"
    echo "  -r, --results DIR         Results directory (default: ./results)"
    echo "  -h, --help                Show this help message"
    echo ""
    echo "Test Types:"
    echo "  smoke         - Quick smoke test (2 minutes)"
    echo "  load          - Standard load test (10 minutes)"
    echo "  stress        - Stress test to find breaking point (15 minutes)"
    echo "  spike         - Spike test for sudden load (5 minutes)"
    echo "  endurance     - Long-running stability test (30 minutes)"
    echo "  catalog       - Catalog service specific test (16 minutes)"
    echo "  cart          - Cart service specific test (16 minutes)"
    echo "  comprehensive - All services combined test (13 minutes)"
    echo ""
    echo "Examples:"
    echo "  $0 -u http://localhost:8080 -t smoke"
    echo "  $0 -u http://myapp.com -t stress -o json"
    echo "  $0 --url http://aws-loadbalancer.com --test load --output influxdb"
}

# Function to check if K6 is installed
check_k6() {
    if ! command -v k6 &> /dev/null; then
        print_error "K6 is not installed. Please install K6 first."
        echo ""
        echo "Installation options:"
        echo "  macOS: brew install k6"
        echo "  Ubuntu/Debian: sudo apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys C5AD17C747E3415A3642D57D77C6C491D6AC1D69 && echo 'deb https://dl.k6.io/deb stable main' | sudo tee /etc/apt/sources.list.d/k6.list && sudo apt-get update && sudo apt-get install k6"
        echo "  Docker: docker pull grafana/k6"
        echo "  Windows: choco install k6"
        exit 1
    fi
    print_success "K6 is installed: $(k6 version)"
}

# Function to create results directory
create_results_dir() {
    if [ ! -d "$RESULTS_DIR" ]; then
        mkdir -p "$RESULTS_DIR"
        print_info "Created results directory: $RESULTS_DIR"
    fi
}

# Function to get test file based on test type
get_test_file() {
    case $TEST_TYPE in
        "catalog")
            echo "catalog-service-test.js"
            ;;
        "cart")
            echo "cart-service-test.js"
            ;;
        "comprehensive")
            echo "load-test-runner.js"
            ;;
        *)
            print_error "Invalid test type: $TEST_TYPE"
            show_usage
            exit 1
            ;;
    esac
}

# Function to get output file extension
get_output_extension() {
    case $OUTPUT_FORMAT in
        "json")
            echo "json"
            ;;
        "influxdb")
            echo "influxdb"
            ;;
        "cloudwatch")
            echo "cloudwatch"
            ;;
        "datadog")
            echo "datadog"
            ;;
        *)
            print_error "Invalid output format: $OUTPUT_FORMAT"
            show_usage
            exit 1
            ;;
    esac
}

# Function to run K6 test
run_k6_test() {
    local test_file=$1
    local output_file=$2
    
    print_info "Starting K6 test..."
    print_info "Test file: $test_file"
    print_info "Base URL: $BASE_URL"
    print_info "Output file: $output_file"
    print_info "Test type: $TEST_TYPE"
    
    # Set environment variable for base URL
    export BASE_URL="$BASE_URL"
    
    # Run K6 test
    k6 run \
        --out "$OUTPUT_FORMAT=$output_file" \
        --env BASE_URL="$BASE_URL" \
        "$test_file"
    
    if [ $? -eq 0 ]; then
        print_success "Test completed successfully!"
        print_info "Results saved to: $output_file"
    else
        print_error "Test failed!"
        exit 1
    fi
}

# Function to run test with custom stages (for smoke, load, stress, spike, endurance)
run_custom_test() {
    local test_file=$1
    local output_file=$2
    
    print_info "Running custom test configuration..."
    print_info "Test type: $TEST_TYPE"
    print_info "Base URL: $BASE_URL"
    print_info "Output file: $output_file"
    
    # Set environment variable for base URL
    export BASE_URL="$BASE_URL"
    
    # Run K6 test with custom stages
    case $TEST_TYPE in
        "smoke")
            k6 run \
                --out "$OUTPUT_FORMAT=$output_file" \
                --env BASE_URL="$BASE_URL" \
                --stage 30s:2 \
                --stage 1m:2 \
                --stage 30s:0 \
                "$test_file"
            ;;
        "load")
            k6 run \
                --out "$OUTPUT_FORMAT=$output_file" \
                --env BASE_URL="$BASE_URL" \
                --stage 2m:10 \
                --stage 5m:10 \
                --stage 2m:20 \
                --stage 1m:0 \
                "$test_file"
            ;;
        "stress")
            k6 run \
                --out "$OUTPUT_FORMAT=$output_file" \
                --env BASE_URL="$BASE_URL" \
                --stage 2m:10 \
                --stage 3m:20 \
                --stage 3m:30 \
                --stage 3m:40 \
                --stage 3m:50 \
                --stage 1m:0 \
                "$test_file"
            ;;
        "spike")
            k6 run \
                --out "$OUTPUT_FORMAT=$output_file" \
                --env BASE_URL="$BASE_URL" \
                --stage 1m:10 \
                --stage 30s:50 \
                --stage 1m:50 \
                --stage 30s:10 \
                --stage 2m:10 \
                "$test_file"
            ;;
        "endurance")
            k6 run \
                --out "$OUTPUT_FORMAT=$output_file" \
                --env BASE_URL="$BASE_URL" \
                --stage 2m:5 \
                --stage 25m:5 \
                --stage 3m:0 \
                "$test_file"
            ;;
    esac
    
    if [ $? -eq 0 ]; then
        print_success "Test completed successfully!"
        print_info "Results saved to: $output_file"
    else
        print_error "Test failed!"
        exit 1
    fi
}

# Function to validate URL
validate_url() {
    if [[ ! $BASE_URL =~ ^https?:// ]]; then
        print_error "Invalid URL format: $BASE_URL"
        print_info "URL should start with http:// or https://"
        exit 1
    fi
}

# Function to check if application is accessible
check_application() {
    print_info "Checking if application is accessible at $BASE_URL..."
    
    if curl -s --head "$BASE_URL" | head -n 1 | grep "HTTP/1.[01] [23].." > /dev/null; then
        print_success "Application is accessible"
    else
        print_warning "Application might not be accessible at $BASE_URL"
        print_info "Make sure the application is running and the URL is correct"
        read -p "Do you want to continue anyway? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -u|--url)
            BASE_URL="$2"
            shift 2
            ;;
        -t|--test)
            TEST_TYPE="$2"
            shift 2
            ;;
        -o|--output)
            OUTPUT_FORMAT="$2"
            shift 2
            ;;
        -r|--results)
            RESULTS_DIR="$2"
            shift 2
            ;;
        -h|--help)
            show_usage
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
done

# Main execution
main() {
    print_info "K6 Performance Testing for Microservices Demo"
    echo "=================================================="
    
    # Check prerequisites
    check_k6
    
    # Validate URL
    validate_url
    
    # Check application accessibility
    check_application
    
    # Create results directory
    create_results_dir
    
    # Generate output filename
    local output_extension=$(get_output_extension)
    local output_file="$RESULTS_DIR/k6_${TEST_TYPE}_${TIMESTAMP}.$output_extension"
    
    # Determine test file and run test
    if [[ "$TEST_TYPE" =~ ^(smoke|load|stress|spike|endurance)$ ]]; then
        # Use comprehensive test runner for these scenarios
        run_custom_test "load-test-runner.js" "$output_file"
    else
        # Use specific test files
        local test_file=$(get_test_file)
        run_k6_test "$test_file" "$output_file"
    fi
    
    print_success "All tests completed!"
    print_info "Results directory: $RESULTS_DIR"
    print_info "Latest result file: $output_file"
    
    # Show summary
    echo ""
    echo "Test Summary:"
    echo "============="
    echo "Test Type: $TEST_TYPE"
    echo "Base URL: $BASE_URL"
    echo "Output Format: $OUTPUT_FORMAT"
    echo "Results File: $output_file"
    echo ""
    echo "To view results:"
    echo "  - JSON: cat $output_file"
    echo "  - InfluxDB: Use Grafana or InfluxDB UI"
    echo "  - CloudWatch: Check AWS CloudWatch console"
    echo "  - Datadog: Check Datadog dashboard"
}

# Run main function
main "$@" 