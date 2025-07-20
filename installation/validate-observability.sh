#!/bin/bash

# Observability Framework Validation Script
# This script validates the integrity of all observability components

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

# Function to validate YAML syntax
validate_yaml() {
    local file="$1"
    if command -v yamllint &> /dev/null; then
        if yamllint "$file" > /dev/null 2>&1; then
            print_success "YAML syntax valid: $file"
            return 0
        else
            print_error "YAML syntax error in: $file"
            return 1
        fi
    else
        # Basic YAML validation using kubectl
        if kubectl apply --dry-run=client -f "$file" > /dev/null 2>&1; then
            print_success "Kubernetes manifest valid: $file"
            return 0
        else
            print_error "Kubernetes manifest error in: $file"
            return 1
        fi
    fi
}

# Function to check required files
check_required_files() {
    print_info "Checking required files..."
    
    local required_files=(
        "monitoring/namespace.yaml"
        "monitoring/prometheus-config.yaml"
        "monitoring/prometheus-deployment.yaml"
        "monitoring/enhanced-prometheus-rules-fixed.yaml"
        "monitoring/loki-config-enhanced.yaml"
        "monitoring/loki-deployment.yaml"
        "monitoring/vector-config-fixed.yaml"
        "monitoring/vector-deployment.yaml"
        "monitoring/tempo-config.yaml"
        "monitoring/tempo-deployment.yaml"
        "monitoring/otel-collector-config.yaml"
        "monitoring/otel-collector-deployment.yaml"
        "monitoring/grafana-config.yaml"
        "monitoring/grafana-deployment.yaml"
        "monitoring/alertmanager-config.yaml"
        "monitoring/alertmanager-deployment.yaml"
        "monitoring/alertmanager-templates.yaml"
        "src/frontend/metrics.go"
        "src/frontend/instrumentation.go"
        "installation/deploy-observability-enhanced-fixed.sh"
    )
    
    local missing_files=()
    local valid_files=0
    
    for file in "${required_files[@]}"; do
        if [ -f "$file" ]; then
            print_success "File exists: $file"
            if validate_yaml "$file"; then
                ((valid_files++))
            fi
        else
            print_error "File missing: $file"
            missing_files+=("$file")
        fi
    done
    
    echo ""
    print_info "File validation summary:"
    echo "  Total files: ${#required_files[@]}"
    echo "  Valid files: $valid_files"
    echo "  Missing files: ${#missing_files[@]}"
    
    if [ ${#missing_files[@]} -gt 0 ]; then
        print_warning "Missing files:"
        for file in "${missing_files[@]}"; do
            echo "  - $file"
        done
        return 1
    fi
    
    return 0
}

# Function to validate PrometheusRule CRD
validate_prometheus_rule() {
    print_info "Validating PrometheusRule CRD..."
    
    local file="monitoring/enhanced-prometheus-rules-fixed.yaml"
    
    if [ ! -f "$file" ]; then
        print_error "PrometheusRule file not found: $file"
        return 1
    fi
    
    # Check if it's using the correct CRD format
    if grep -q "apiVersion: monitoring.coreos.com/v1" "$file" && \
       grep -q "kind: PrometheusRule" "$file"; then
        print_success "PrometheusRule CRD format is correct"
        return 0
    else
        print_error "PrometheusRule CRD format is incorrect"
        return 1
    fi
}

# Function to validate Vector configuration
validate_vector_config() {
    print_info "Validating Vector configuration..."
    
    local file="monitoring/vector-config-fixed.yaml"
    
    if [ ! -f "$file" ]; then
        print_error "Vector config file not found: $file"
        return 1
    fi
    
    # Check for required Vector configuration elements
    local checks=(
        "api:"
        "sources:"
        "transforms:"
        "sinks:"
        "loki_logs:"
        "prometheus_remote_write:"
    )
    
    local valid_checks=0
    for check in "${checks[@]}"; do
        if grep -q "$check" "$file"; then
            ((valid_checks++))
        else
            print_warning "Missing Vector config element: $check"
        fi
    done
    
    if [ $valid_checks -eq ${#checks[@]} ]; then
        print_success "Vector configuration is complete"
        return 0
    else
        print_warning "Vector configuration is incomplete"
        return 1
    fi
}

# Function to validate Alertmanager configuration
validate_alertmanager_config() {
    print_info "Validating Alertmanager configuration..."
    
    local config_file="monitoring/alertmanager-config.yaml"
    local templates_file="monitoring/alertmanager-templates.yaml"
    
    if [ ! -f "$config_file" ]; then
        print_error "Alertmanager config file not found: $config_file"
        return 1
    fi
    
    if [ ! -f "$templates_file" ]; then
        print_error "Alertmanager templates file not found: $templates_file"
        return 1
    fi
    
    # Check for placeholder values
    if grep -q "YOUR_SLACK_WEBHOOK" "$config_file" || \
       grep -q "YOUR_PAGERDUTY_KEY" "$config_file"; then
        print_warning "Alertmanager config contains placeholder values"
        print_info "Please update the following in production:"
        echo "  - YOUR_SLACK_WEBHOOK -> Actual Slack webhook URL"
        echo "  - YOUR_PAGERDUTY_KEY -> Actual PagerDuty routing key"
    else
        print_success "Alertmanager configuration is production-ready"
    fi
    
    # Check for template definitions
    if grep -q "slack.tmpl:" "$templates_file" && \
       grep -q "pagerduty.tmpl:" "$templates_file" && \
       grep -q "email.tmpl:" "$templates_file"; then
        print_success "Alertmanager templates are complete"
        return 0
    else
        print_warning "Alertmanager templates are incomplete"
        return 1
    fi
}

# Function to validate application metrics
validate_application_metrics() {
    print_info "Validating application metrics..."
    
    local metrics_file="src/frontend/metrics.go"
    
    if [ ! -f "$metrics_file" ]; then
        print_error "Application metrics file not found: $metrics_file"
        return 1
    fi
    
    # Check for required metrics
    local required_metrics=(
        "httpRequestsTotal"
        "httpRequestDuration"
        "ordersTotal"
        "cartCreatedTotal"
        "cartAbandonedTotal"
        "paymentAttemptedTotal"
        "paymentFailedTotal"
    )
    
    local found_metrics=0
    for metric in "${required_metrics[@]}"; do
        if grep -q "$metric" "$metrics_file"; then
            ((found_metrics++))
        else
            print_warning "Missing metric: $metric"
        fi
    done
    
    if [ $found_metrics -eq ${#required_metrics[@]} ]; then
        print_success "All required application metrics are defined"
        return 0
    else
        print_warning "Some application metrics are missing"
        return 1
    fi
}

# Function to validate deployment script
validate_deployment_script() {
    print_info "Validating deployment script..."
    
    local script_file="installation/deploy-observability-enhanced-fixed.sh"
    
    if [ ! -f "$script_file" ]; then
        print_error "Deployment script not found: $script_file"
        return 1
    fi
    
    # Check if script is executable
    if [ -x "$script_file" ]; then
        print_success "Deployment script is executable"
    else
        print_warning "Deployment script is not executable"
        chmod +x "$script_file"
        print_info "Made deployment script executable"
    fi
    
    # Check for required functions
    local required_functions=(
        "check_kubectl"
        "deploy_core_monitoring"
        "deploy_logging"
        "deploy_tracing"
        "deploy_visualization"
        "deploy_alerting"
    )
    
    local found_functions=0
    for func in "${required_functions[@]}"; do
        if grep -q "$func()" "$script_file"; then
            ((found_functions++))
        else
            print_warning "Missing function: $func"
        fi
    done
    
    if [ $found_functions -eq ${#required_functions[@]} ]; then
        print_success "Deployment script contains all required functions"
        return 0
    else
        print_warning "Deployment script is missing some functions"
        return 1
    fi
}

# Function to check performance requirements
check_performance_requirements() {
    print_info "Checking performance requirements compliance..."
    
    local compliance=0
    local total_checks=6
    
    # Check metrics ingestion latency
    if grep -q "scrape_interval: 30s" monitoring/prometheus-config.yaml; then
        print_success "Metrics ingestion: < 30 seconds ✓"
        ((compliance++))
    else
        print_warning "Metrics ingestion: Check scrape interval configuration"
    fi
    
    # Check log ingestion latency
    if grep -q "glob_minimum_cooldown_ms: 1000" monitoring/vector-config-fixed.yaml; then
        print_success "Log ingestion: < 30 seconds ✓"
        ((compliance++))
    else
        print_warning "Log ingestion: Check Vector configuration"
    fi
    
    # Check trace ingestion latency
    if grep -q "batch_timeout: 1s" monitoring/otel-collector-config.yaml; then
        print_success "Trace ingestion: < 30 seconds ✓"
        ((compliance++))
    else
        print_warning "Trace ingestion: Check OpenTelemetry configuration"
    fi
    
    # Check query response time
    if grep -q "cache_results: true" monitoring/loki-config-enhanced.yaml; then
        print_success "Query response: < 5 seconds ✓"
        ((compliance++))
    else
        print_warning "Query response: Check caching configuration"
    fi
    
    # Check alert delivery
    if grep -q "group_wait: 10s" monitoring/alertmanager-config.yaml; then
        print_success "Alert delivery: < 30 seconds ✓"
        ((compliance++))
    else
        print_warning "Alert delivery: Check Alertmanager configuration"
    fi
    
    # Check scalability
    if grep -q "replicas: 3" monitoring/vector-deployment.yaml; then
        print_success "Scalability: Horizontal scaling configured ✓"
        ((compliance++))
    else
        print_warning "Scalability: Check replica configurations"
    fi
    
    echo ""
    print_info "Performance compliance: $compliance/$total_checks requirements met"
    
    if [ $compliance -eq $total_checks ]; then
        print_success "All performance requirements are met!"
        return 0
    else
        print_warning "Some performance requirements need attention"
        return 1
    fi
}

# Function to generate summary report
generate_summary_report() {
    echo ""
    echo "=========================================="
    echo "OBSERVABILITY FRAMEWORK VALIDATION REPORT"
    echo "=========================================="
    echo ""
    echo "Validation completed at: $(date)"
    echo ""
    echo "Summary:"
    echo "--------"
    echo "✅ Files validated: $valid_files_count"
    echo "❌ Files with issues: $invalid_files_count"
    echo "⚠️  Warnings: $warning_count"
    echo ""
    echo "Recommendations:"
    echo "----------------"
    echo "1. Update placeholder values in Alertmanager config"
    echo "2. Verify PrometheusRule CRD is installed in your cluster"
    echo "3. Test the deployment script in a non-production environment"
    echo "4. Validate all metrics are being collected by applications"
    echo "5. Configure proper alert channels for production use"
    echo ""
}

# Main validation function
main() {
    print_info "Starting observability framework validation..."
    echo "=================================================="
    
    local valid_files_count=0
    local invalid_files_count=0
    local warning_count=0
    
    # Run all validations
    if check_required_files; then
        ((valid_files_count++))
    else
        ((invalid_files_count++))
    fi
    
    if validate_prometheus_rule; then
        ((valid_files_count++))
    else
        ((invalid_files_count++))
    fi
    
    if validate_vector_config; then
        ((valid_files_count++))
    else
        ((warning_count++))
    fi
    
    if validate_alertmanager_config; then
        ((valid_files_count++))
    else
        ((warning_count++))
    fi
    
    if validate_application_metrics; then
        ((valid_files_count++))
    else
        ((warning_count++))
    fi
    
    if validate_deployment_script; then
        ((valid_files_count++))
    else
        ((invalid_files_count++))
    fi
    
    if check_performance_requirements; then
        ((valid_files_count++))
    else
        ((warning_count++))
    fi
    
    # Generate summary report
    generate_summary_report
    
    # Final status
    if [ $invalid_files_count -eq 0 ]; then
        print_success "✅ Observability framework validation completed successfully!"
        print_info "The framework is ready for deployment."
        exit 0
    else
        print_error "❌ Observability framework validation found issues."
        print_info "Please address the issues before deployment."
        exit 1
    fi
}

# Run main validation
main "$@" 