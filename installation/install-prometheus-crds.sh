#!/bin/bash

# Script to install Prometheus Operator CRDs using server-side apply
# This handles the annotation size limit issue

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    print_error "kubectl is not installed or not in PATH"
    exit 1
fi

# Check if we can connect to the cluster
if ! kubectl cluster-info &> /dev/null; then
    print_error "Cannot connect to Kubernetes cluster"
    exit 1
fi

print_info "Installing Prometheus Operator CRDs using server-side apply..."

# CRD URLs
CRD_URLS=(
    "https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/main/example/prometheus-operator-crd/monitoring.coreos.com_prometheusrules.yaml"
    "https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/main/example/prometheus-operator-crd/monitoring.coreos.com_servicemonitors.yaml"
    "https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/main/example/prometheus-operator-crd/monitoring.coreos.com_prometheuses.yaml"
)

# CRD names for verification
CRD_NAMES=(
    "prometheusrules.monitoring.coreos.com"
    "servicemonitors.monitoring.coreos.com"
    "prometheuses.monitoring.coreos.com"
)

# Install CRDs
for i in "${!CRD_URLS[@]}"; do
    url="${CRD_URLS[$i]}"
    crd_name="${CRD_NAMES[$i]}"
    
    print_info "Installing CRD: $crd_name"
    
    # Check if CRD already exists
    if kubectl get crd "$crd_name" &> /dev/null; then
        print_info "CRD $crd_name already exists, skipping..."
        continue
    fi
    
    # Install CRD using server-side apply
    if kubectl apply --server-side -f "$url"; then
        print_success "Successfully installed CRD: $crd_name"
    else
        print_error "Failed to install CRD: $crd_name"
        exit 1
    fi
done

# Verify installation
print_info "Verifying CRD installation..."
for crd_name in "${CRD_NAMES[@]}"; do
    if kubectl get crd "$crd_name" &> /dev/null; then
        print_success "CRD $crd_name is installed and ready"
    else
        print_error "CRD $crd_name is not installed"
        exit 1
    fi
done

print_success "All Prometheus Operator CRDs installed successfully!"
print_info "You can now deploy Prometheus and related monitoring components." 