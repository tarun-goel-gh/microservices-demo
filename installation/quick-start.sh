#!/bin/bash

# Quick Start Installation Script for Observability Framework
# This script provides a streamlined installation process

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

# Function to check prerequisites
check_prerequisites() {
    print_info "Checking prerequisites..."
    
    # Check kubectl
    if ! command -v kubectl &> /dev/null; then
        print_error "kubectl is not installed. Please install kubectl first."
        exit 1
    fi
    
    # Check cluster access
    if ! kubectl cluster-info &> /dev/null; then
        print_error "Cannot connect to Kubernetes cluster. Please check your kubeconfig."
        exit 1
    fi
    
    # Check cluster resources
    print_info "Checking cluster resources..."
    kubectl get nodes
    
    print_success "Prerequisites check passed!"
}

# Function to validate installation files
validate_files() {
    print_info "Validating installation files..."
    
    local required_files=(
        "monitoring/namespace.yaml"
        "monitoring/prometheus-config.yaml"
        "monitoring/prometheus-deployment.yaml"
        "monitoring/enhanced-prometheus-rules-fixed.yaml"
        "monitoring/grafana-config.yaml"
        "monitoring/grafana-deployment.yaml"
        "monitoring/loki-config-enhanced.yaml"
        "monitoring/loki-deployment.yaml"
        "monitoring/vector-config-fixed.yaml"
        "monitoring/vector-deployment.yaml"
        "monitoring/tempo-config.yaml"
        "monitoring/tempo-deployment.yaml"
        "monitoring/alertmanager-config.yaml"
        "monitoring/alertmanager-deployment.yaml"
        "monitoring/alertmanager-templates.yaml"
    )
    
    for file in "${required_files[@]}"; do
        if [ ! -f "$file" ]; then
            print_error "Required file not found: $file"
            exit 1
        fi
    done
    
    print_success "All required files found!"
}

# Function to install CRDs
install_crds() {
    print_info "Installing required CRDs..."
    
    # Check if PrometheusRule CRD exists
    if ! kubectl get crd prometheusrules.monitoring.coreos.com &> /dev/null; then
        print_info "Installing PrometheusRule CRD..."
        kubectl apply -f https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/main/example/prometheus-operator-crd/monitoring.coreos.com_prometheusrules.yaml
        print_success "PrometheusRule CRD installed!"
    else
        print_success "PrometheusRule CRD already exists!"
    fi
}

# Function to deploy observability stack
deploy_observability() {
    print_info "Deploying observability framework..."
    
    # Create namespace
    print_info "Creating monitoring namespace..."
    kubectl apply -f monitoring/namespace.yaml
    
    # Deploy core monitoring
    print_info "Deploying core monitoring components..."
    kubectl apply -f monitoring/prometheus-config.yaml
    kubectl apply -f monitoring/prometheus-deployment.yaml
    kubectl apply -f monitoring/enhanced-prometheus-rules-fixed.yaml
    
    kubectl apply -f monitoring/grafana-config.yaml
    kubectl apply -f monitoring/grafana-deployment.yaml
    kubectl apply -f monitoring/grafana-datasources.yaml
    kubectl apply -f monitoring/grafana-dashboards.yaml
    
    # Deploy logging stack
    print_info "Deploying logging stack..."
    kubectl apply -f monitoring/loki-config-enhanced.yaml
    kubectl apply -f monitoring/loki-deployment.yaml
    kubectl apply -f monitoring/vector-config-fixed.yaml
    kubectl apply -f monitoring/vector-deployment.yaml
    kubectl apply -f monitoring/promtail-config.yaml
    kubectl apply -f monitoring/promtail-daemonset.yaml
    
    # Deploy tracing stack
    print_info "Deploying tracing stack..."
    kubectl apply -f monitoring/tempo-config.yaml
    kubectl apply -f monitoring/tempo-deployment.yaml
    kubectl apply -f monitoring/otel-collector-config.yaml
    kubectl apply -f monitoring/otel-collector-deployment.yaml
    
    # Deploy alerting stack
    print_info "Deploying alerting stack..."
    kubectl apply -f monitoring/alertmanager-config.yaml
    kubectl apply -f monitoring/alertmanager-deployment.yaml
    kubectl apply -f monitoring/alertmanager-templates.yaml
    
    # Deploy additional components
    print_info "Deploying additional components..."
    kubectl apply -f monitoring/node-exporter.yaml
    kubectl apply -f monitoring/kube-state-metrics.yaml
    kubectl apply -f monitoring/mimir-config.yaml
    kubectl apply -f monitoring/mimir-deployment.yaml
    
    print_success "Observability framework deployed!"
}

# Function to wait for deployments
wait_for_deployments() {
    print_info "Waiting for all deployments to be ready..."
    
    local deployments=(
        "prometheus"
        "grafana"
        "loki"
        "vector"
        "tempo"
        "alertmanager"
        "mimir"
    )
    
    for deployment in "${deployments[@]}"; do
        print_info "Waiting for $deployment deployment..."
        kubectl wait --for=condition=available --timeout=300s deployment/$deployment -n monitoring
        print_success "$deployment deployment is ready!"
    done
}

# Function to verify installation
verify_installation() {
    print_info "Verifying installation..."
    
    # Check all pods
    print_info "Checking pod status..."
    kubectl get pods -n monitoring
    
    # Check all services
    print_info "Checking service status..."
    kubectl get services -n monitoring
    
    # Test component health
    print_info "Testing component health..."
    
    # Test Prometheus
    if kubectl port-forward -n monitoring svc/prometheus-service 9090:9090 --timeout=10s &> /dev/null; then
        if curl -s http://localhost:9090/api/v1/status/config &> /dev/null; then
            print_success "Prometheus is healthy!"
        else
            print_warning "Prometheus health check failed"
        fi
        pkill -f "port-forward.*prometheus" || true
    fi
    
    # Test Grafana
    if kubectl port-forward -n monitoring svc/grafana-service 3000:3000 --timeout=10s &> /dev/null; then
        if curl -s http://localhost:3000/api/health &> /dev/null; then
            print_success "Grafana is healthy!"
        else
            print_warning "Grafana health check failed"
        fi
        pkill -f "port-forward.*grafana" || true
    fi
    
    print_success "Installation verification completed!"
}

# Function to display access information
display_access_info() {
    echo ""
    echo "=========================================="
    echo "🚀 OBSERVABILITY FRAMEWORK INSTALLED!"
    echo "=========================================="
    echo ""
    echo "Access URLs (use kubectl port-forward):"
    echo "----------------------------------------"
    echo "📊 Grafana Dashboard:"
    echo "   kubectl port-forward -n monitoring svc/grafana-service 3000:3000"
    echo "   http://localhost:3000 (admin/admin)"
    echo ""
    echo "📈 Prometheus:"
    echo "   kubectl port-forward -n monitoring svc/prometheus-service 9090:9090"
    echo "   http://localhost:9090"
    echo ""
    echo "🚨 Alertmanager:"
    echo "   kubectl port-forward -n monitoring svc/alertmanager-service 9093:9093"
    echo "   http://localhost:9093"
    echo ""
    echo "📝 Loki (Logs):"
    echo "   kubectl port-forward -n monitoring svc/loki-service 3100:3100"
    echo "   http://localhost:3100"
    echo ""
    echo "🔍 Tempo (Traces):"
    echo "   kubectl port-forward -n monitoring svc/tempo-service 3200:3200"
    echo "   http://localhost:3200"
    echo ""
    echo "Next Steps:"
    echo "-----------"
    echo "1. Update Alertmanager config with your webhook URLs"
    echo "2. Configure your applications to expose metrics"
    echo "3. Set up custom dashboards for your services"
    echo "4. Configure alert channels for production use"
    echo ""
    echo "Documentation:"
    echo "--------------"
    echo "- INSTALLATION_GUIDE.md - Complete installation guide"
    echo "- monitoring/OBSERVABILITY_FRAMEWORK.md - Architecture docs"
    echo "- installation/TROUBLESHOOTING.md - Troubleshooting guide"
    echo ""
}

# Function to show configuration notes
show_configuration_notes() {
    echo ""
    print_warning "IMPORTANT: Configuration Updates Required"
    echo "=================================================="
    echo ""
    echo "Before using in production, update these configurations:"
    echo ""
    echo "1. Alertmanager Configuration:"
    echo "   kubectl edit configmap alertmanager-config -n monitoring"
    echo "   - Replace YOUR_SLACK_WEBHOOK with actual Slack webhook URL"
    echo "   - Replace YOUR_PAGERDUTY_KEY with actual PagerDuty routing key"
    echo "   - Replace YOUR_EMAIL with actual email address"
    echo ""
    echo "2. External Access:"
    echo "   kubectl patch svc grafana-service -n monitoring -p '{\"spec\":{\"type\":\"LoadBalancer\"}}'"
    echo ""
    echo "3. Application Integration:"
    echo "   - Copy src/frontend/metrics.go to your applications"
    echo "   - Expose /metrics endpoints in your services"
    echo "   - Configure service discovery for your applications"
    echo ""
}

# Main function
main() {
    echo "🚀 Observability Framework Quick Start Installation"
    echo "=================================================="
    echo ""
    
    # Check prerequisites
    check_prerequisites
    
    # Validate files
    validate_files
    
    # Install CRDs
    install_crds
    
    # Deploy observability stack
    deploy_observability
    
    # Wait for deployments
    wait_for_deployments
    
    # Verify installation
    verify_installation
    
    # Display access information
    display_access_info
    
    # Show configuration notes
    show_configuration_notes
    
    print_success "🎉 Installation completed successfully!"
    print_info "Run './installation/validate-observability.sh' to perform a full validation."
}

# Run main function
main "$@" 