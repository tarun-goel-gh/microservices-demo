#!/bin/bash

# Test script for EKS cluster wait functionality
# This script tests the different methods of waiting for EKS cluster readiness

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

# Configuration variables
CLUSTER_NAME="test-cluster"
REGION="us-west-2"

# Function to test eksctl utils wait
test_eksctl_utils_wait() {
    print_info "Testing eksctl utils wait command..."
    
    if eksctl utils wait --help &> /dev/null; then
        print_success "eksctl utils wait command is available"
        return 0
    else
        print_warning "eksctl utils wait command is not available"
        return 1
    fi
}

# Function to test AWS CLI cluster status
test_aws_cli_cluster_status() {
    print_info "Testing AWS CLI cluster status check..."
    
    if aws eks describe-cluster --name $CLUSTER_NAME --region $REGION --query 'cluster.status' --output text &> /dev/null; then
        CLUSTER_STATUS=$(aws eks describe-cluster --name $CLUSTER_NAME --region $REGION --query 'cluster.status' --output text)
        print_info "Cluster status: $CLUSTER_STATUS"
        return 0
    else
        print_warning "Could not get cluster status (cluster may not exist)"
        return 1
    fi
}

# Function to test AWS CLI node group status
test_aws_cli_nodegroup_status() {
    print_info "Testing AWS CLI node group status check..."
    
    if aws eks describe-nodegroup --cluster-name $CLUSTER_NAME --nodegroup-name standard-workers --region $REGION --query 'nodegroup.status' --output text &> /dev/null; then
        NODE_STATUS=$(aws eks describe-nodegroup --cluster-name $CLUSTER_NAME --nodegroup-name standard-workers --region $REGION --query 'nodegroup.status' --output text)
        print_info "Node group status: $NODE_STATUS"
        return 0
    else
        print_warning "Could not get node group status (node group may not exist)"
        return 1
    fi
}

# Function to test kubectl connectivity
test_kubectl_connectivity() {
    print_info "Testing kubectl connectivity..."
    
    if kubectl cluster-info &> /dev/null; then
        print_success "kubectl connectivity is working"
        return 0
    else
        print_warning "kubectl connectivity is not working"
        return 1
    fi
}

# Main function
main() {
    echo "🧪 EKS Wait Functionality Test"
    echo "=============================="
    echo ""
    
    # Check prerequisites
    print_info "Checking prerequisites..."
    
    # Check eksctl
    if ! command -v eksctl &> /dev/null; then
        print_error "eksctl is not installed"
        exit 1
    fi
    
    # Check AWS CLI
    if ! command -v aws &> /dev/null; then
        print_error "AWS CLI is not installed"
        exit 1
    fi
    
    # Check kubectl
    if ! command -v kubectl &> /dev/null; then
        print_error "kubectl is not installed"
        exit 1
    fi
    
    print_success "Prerequisites check passed!"
    echo ""
    
    # Test eksctl utils wait
    test_eksctl_utils_wait
    echo ""
    
    # Test AWS CLI cluster status
    test_aws_cli_cluster_status
    echo ""
    
    # Test AWS CLI node group status
    test_aws_cli_nodegroup_status
    echo ""
    
    # Test kubectl connectivity
    test_kubectl_connectivity
    echo ""
    
    print_info "Test completed!"
    echo ""
    print_info "Summary:"
    echo "- eksctl utils wait: $(test_eksctl_utils_wait && echo "Available" || echo "Not available")"
    echo "- AWS CLI cluster status: $(test_aws_cli_cluster_status && echo "Working" || echo "Not working")"
    echo "- AWS CLI node group status: $(test_aws_cli_nodegroup_status && echo "Working" || echo "Not working")"
    echo "- kubectl connectivity: $(test_kubectl_connectivity && echo "Working" || echo "Not working")"
}

# Run main function
main "$@" 