#!/bin/bash

# Complete Stack Cleanup Script
# This script orchestrates the complete cleanup of online boutique + observability framework

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
CLEANUP_TYPE="all"  # Options: all, app-only, observability-only
NAMESPACE="online-boutique"
CONFIRM_CLEANUP="false"

# Function to show help
show_help() {
    echo "Complete Stack Cleanup Script"
    echo "============================"
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --type TYPE           Cleanup type: all, app-only, observability-only (default: all)"
    echo "  --namespace NAME      Application namespace (default: online-boutique)"
    echo "  --confirm             Skip confirmation prompt"
    echo "  --help                Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0                                    # Clean up everything (with confirmation)"
    echo "  $0 --type app-only                    # Clean up only the application"
    echo "  $0 --type observability-only          # Clean up only observability"
    echo "  $0 --confirm                          # Clean up everything without confirmation"
    echo ""
}

# Function to parse command line arguments
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --type)
                CLEANUP_TYPE="$2"
                shift 2
                ;;
            --namespace)
                NAMESPACE="$2"
                shift 2
                ;;
            --confirm)
                CONFIRM_CLEANUP="true"
                shift
                ;;
            --help)
                show_help
                exit 0
                ;;
            *)
                print_error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
}

# Function to check prerequisites
check_prerequisites() {
    print_info "Checking prerequisites..."
    
    # Check kubectl
    if ! command -v kubectl &> /dev/null; then
        print_error "kubectl is not installed."
        exit 1
    fi
    
    # Check cluster access
    if ! kubectl cluster-info &> /dev/null; then
        print_error "Cannot connect to Kubernetes cluster."
        exit 1
    fi
    
    print_success "Prerequisites check passed!"
}

# Function to get user confirmation
get_confirmation() {
    if [ "$CONFIRM_CLEANUP" = "true" ]; then
        return 0
    fi
    
    echo ""
    print_warning "⚠️  WARNING: This will permanently delete resources!"
    echo ""
    
    case $CLEANUP_TYPE in
        "all")
            echo "You are about to clean up:"
            echo "✅ Online boutique application (namespace: $NAMESPACE)"
            echo "✅ Complete observability framework (namespace: monitoring)"
            echo "✅ AWS infrastructure (if deployed on AWS)"
            echo "✅ All associated persistent volumes and load balancers"
            ;;
        "app-only")
            echo "You are about to clean up:"
            echo "✅ Online boutique application (namespace: $NAMESPACE)"
            echo "✅ All associated persistent volumes and load balancers"
            ;;
        "observability-only")
            echo "You are about to clean up:"
            echo "✅ Complete observability framework (namespace: monitoring)"
            echo "✅ All associated persistent volumes and load balancers"
            ;;
    esac
    
    echo ""
    read -p "Are you sure you want to continue? (yes/no): " -r
    echo
    
    if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
        print_info "Cleanup cancelled by user."
        exit 0
    fi
}

# Function to detect deployment type
detect_deployment_type() {
    print_info "Detecting deployment type..."
    
    # Check if AWS Load Balancer Controller exists
    if kubectl get deployment aws-load-balancer-controller -n kube-system &> /dev/null; then
        DEPLOYMENT_TYPE="aws"
        print_info "Detected AWS deployment"
    else
        DEPLOYMENT_TYPE="local"
        print_info "Detected local deployment"
    fi
}

# Function to cleanup application
cleanup_application() {
    print_info "Phase 1: Cleaning up Online Boutique Application"
    echo "====================================================="
    
    # Check if namespace exists
    if kubectl get namespace $NAMESPACE &> /dev/null; then
        print_info "Cleaning up application namespace: $NAMESPACE"
        ./installation/cleanup-online-boutique.sh --namespace $NAMESPACE --confirm
        print_success "Application cleanup completed!"
    else
        print_warning "Application namespace $NAMESPACE not found - skipping"
    fi
}

# Function to cleanup observability
cleanup_observability() {
    print_info "Phase 2: Cleaning up Observability Framework"
    echo "================================================="
    
    # Check if monitoring namespace exists
    if kubectl get namespace monitoring &> /dev/null; then
        if [ "$DEPLOYMENT_TYPE" = "aws" ]; then
            print_info "Cleaning up AWS observability framework..."
            ./installation/cleanup-aws-observability.sh --confirm
        else
            print_info "Cleaning up local observability framework..."
            kubectl delete namespace monitoring --ignore-not-found=true
        fi
        print_success "Observability cleanup completed!"
    else
        print_warning "Monitoring namespace not found - skipping"
    fi
}

# Function to cleanup orphaned resources
cleanup_orphaned_resources() {
    print_info "Phase 3: Cleaning up Orphaned Resources"
    echo "============================================"
    
    # Clean up orphaned persistent volumes
    print_info "Cleaning up orphaned persistent volumes..."
    kubectl get pv | grep Released | awk '{print $1}' | xargs -r kubectl delete pv --ignore-not-found=true
    
    # Clean up orphaned persistent volume claims
    print_info "Cleaning up orphaned persistent volume claims..."
    kubectl get pvc --all-namespaces | grep Pending | awk '{print $1, $2}' | while read ns name; do
        kubectl delete pvc $name -n $ns --ignore-not-found=true
    done
    
    # Clean up orphaned load balancers (AWS only)
    if [ "$DEPLOYMENT_TYPE" = "aws" ]; then
        print_info "Cleaning up orphaned load balancers..."
        # This would require AWS CLI and proper permissions
        print_warning "Manual cleanup of orphaned AWS load balancers may be required"
    fi
    
    print_success "Orphaned resources cleanup completed!"
}

# Function to verify cleanup
verify_cleanup() {
    print_info "Phase 4: Verifying Cleanup"
    echo "=============================="
    
    # Check application namespace
    if [ "$CLEANUP_TYPE" = "all" ] || [ "$CLEANUP_TYPE" = "app-only" ]; then
        if kubectl get namespace $NAMESPACE &> /dev/null; then
            print_warning "Application namespace $NAMESPACE still exists"
        else
            print_success "Application namespace $NAMESPACE cleaned up successfully"
        fi
    fi
    
    # Check monitoring namespace
    if [ "$CLEANUP_TYPE" = "all" ] || [ "$CLEANUP_TYPE" = "observability-only" ]; then
        if kubectl get namespace monitoring &> /dev/null; then
            print_warning "Monitoring namespace still exists"
        else
            print_success "Monitoring namespace cleaned up successfully"
        fi
    fi
    
    # Check for remaining resources
    print_info "Checking for remaining resources..."
    
    # Check remaining pods
    REMAINING_PODS=$(kubectl get pods --all-namespaces --ignore-not-found=true | grep -v "kube-system\|default" | wc -l)
    if [ "$REMAINING_PODS" -gt 0 ]; then
        print_warning "Found $REMAINING_PODS remaining pods in non-system namespaces"
        kubectl get pods --all-namespaces --ignore-not-found=true | grep -v "kube-system\|default"
    else
        print_success "No remaining pods found"
    fi
    
    # Check remaining services
    REMAINING_SVCS=$(kubectl get svc --all-namespaces --ignore-not-found=true | grep -v "kube-system\|default" | wc -l)
    if [ "$REMAINING_SVCS" -gt 0 ]; then
        print_warning "Found $REMAINING_SVCS remaining services in non-system namespaces"
        kubectl get svc --all-namespaces --ignore-not-found=true | grep -v "kube-system\|default"
    else
        print_success "No remaining services found"
    fi
    
    print_success "Cleanup verification completed!"
}

# Function to display cleanup summary
display_cleanup_summary() {
    echo ""
    echo "=========================================="
    echo "🧹 CLEANUP COMPLETED SUCCESSFULLY!"
    echo "=========================================="
    echo ""
    echo "Cleanup Type: $CLEANUP_TYPE"
    echo "Deployment Type: $DEPLOYMENT_TYPE"
    echo "Application Namespace: $NAMESPACE"
    echo ""
    
    case $CLEANUP_TYPE in
        "all")
            echo "✅ Online boutique application removed"
            echo "✅ Observability framework removed"
            echo "✅ AWS infrastructure cleaned up (if applicable)"
            echo "✅ Orphaned resources cleaned up"
            ;;
        "app-only")
            echo "✅ Online boutique application removed"
            echo "⏭️  Observability framework preserved"
            echo "✅ Orphaned resources cleaned up"
            ;;
        "observability-only")
            echo "⏭️  Online boutique application preserved"
            echo "✅ Observability framework removed"
            echo "✅ Orphaned resources cleaned up"
            ;;
    esac
    
    echo ""
    echo "Next Steps:"
    echo "-----------"
    echo "1. Verify no unwanted resources remain"
    echo "2. Check AWS console for any remaining resources (if applicable)"
    echo "3. Consider cleaning up any remaining persistent volumes"
    echo "4. Review and clean up any remaining load balancers"
    echo ""
    
    if [ "$DEPLOYMENT_TYPE" = "aws" ]; then
        echo "AWS-Specific Cleanup:"
        echo "---------------------"
        echo "Check for remaining AWS resources:"
        echo "- Load Balancers: AWS Console > EC2 > Load Balancers"
        echo "- EBS Volumes: AWS Console > EC2 > Volumes"
        echo "- Security Groups: AWS Console > EC2 > Security Groups"
        echo "- IAM Roles: AWS Console > IAM > Roles"
        echo ""
    fi
}

# Main function
main() {
    echo "🧹 Complete Stack Cleanup"
    echo "========================="
    echo ""
    echo "This script will clean up:"
    echo "1. Online boutique microservices application"
    echo "2. Observability framework (monitoring, logging, tracing)"
    echo "3. Orphaned resources (PVs, PVCs, Load Balancers)"
    echo "4. Verify complete cleanup"
    echo ""
    echo "Configuration:"
    echo "- Cleanup Type: $CLEANUP_TYPE"
    echo "- Application Namespace: $NAMESPACE"
    echo "- Confirm Cleanup: $CONFIRM_CLEANUP"
    echo ""
    
    # Parse command line arguments
    parse_arguments "$@"
    
    # Check prerequisites
    check_prerequisites
    
    # Detect deployment type
    detect_deployment_type
    
    # Get user confirmation
    get_confirmation
    
    # Perform cleanup based on type
    case $CLEANUP_TYPE in
        "all")
            cleanup_application
            cleanup_observability
            ;;
        "app-only")
            cleanup_application
            ;;
        "observability-only")
            cleanup_observability
            ;;
        *)
            print_error "Invalid cleanup type: $CLEANUP_TYPE"
            exit 1
            ;;
    esac
    
    # Clean up orphaned resources
    cleanup_orphaned_resources
    
    # Verify cleanup
    verify_cleanup
    
    # Display cleanup summary
    display_cleanup_summary
    
    print_success "🎉 Complete stack cleanup finished successfully!"
    print_info "All requested resources have been cleaned up!"
}

# Run main function
main "$@" 