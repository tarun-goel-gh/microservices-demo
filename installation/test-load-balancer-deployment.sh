#!/bin/bash

# Test script for AWS Load Balancer Controller deployment
# This script tests different deployment methods

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

# Test Helm availability
print_info "Testing Helm availability..."
if command -v helm &> /dev/null; then
    print_success "Helm is available: $(helm version --short)"
else
    print_error "Helm is not available"
    exit 1
fi

# Test Helm repository
print_info "Testing Helm repository..."
if helm repo add eks https://aws.github.io/eks-charts &> /dev/null; then
    print_success "Helm repository added successfully"
else
    print_warning "Helm repository already exists or failed to add"
fi

helm repo update

# Test chart availability
print_info "Testing chart availability..."
if helm search repo eks/aws-load-balancer-controller &> /dev/null; then
    print_success "AWS Load Balancer Controller chart is available"
else
    print_error "AWS Load Balancer Controller chart is not available"
    exit 1
fi

# Test kustomize paths
print_info "Testing kustomize paths..."
kustomize_paths=(
    "github.com/kubernetes-sigs/aws-load-balancer-controller//deploy/eks?ref=v2.7.1"
    "github.com/kubernetes-sigs/aws-load-balancer-controller//deploy/eks/chart?ref=v2.7.1"
    "github.com/kubernetes-sigs/aws-load-balancer-controller//deploy/eks?ref=v2.6.0"
)

for path in "${kustomize_paths[@]}"; do
    print_info "Testing kustomize path: $path"
    if kubectl apply -k "$path" --dry-run=client &> /dev/null; then
        print_success "Kustomize path works: $path"
        break
    else
        print_warning "Kustomize path failed: $path"
    fi
done

print_success "Load Balancer Controller deployment test completed!" 