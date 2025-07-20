#!/bin/bash

# Online Boutique Microservices Cleanup Script
# This script removes the online boutique application

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
NAMESPACE="online-boutique"
DEPLOYMENT_METHOD="kubernetes"

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

# Function to confirm cleanup
confirm_cleanup() {
    echo ""
    print_warning "⚠️  WARNING: This will delete the online boutique application!"
    echo "================================================================"
    echo ""
    echo "The following resources will be deleted:"
    echo "- Namespace: $NAMESPACE"
    echo "- All microservices (frontend, cartservice, etc.)"
    echo "- All services and endpoints"
    echo "- All deployments and pods"
    echo "- All persistent volumes and claims"
    echo "- All configuration maps and secrets"
    echo ""
    echo "This action is IRREVERSIBLE!"
    echo ""
    
    read -p "Are you sure you want to continue? (yes/no): " confirm
    
    if [ "$confirm" != "yes" ]; then
        print_info "Cleanup cancelled."
        exit 0
    fi
    
    echo ""
    print_warning "Proceeding with cleanup..."
    echo ""
}

# Function to detect deployment method
detect_deployment_method() {
    print_info "Detecting deployment method..."
    
    # Check if Helm release exists
    if command -v helm &> /dev/null; then
        if helm list -n $NAMESPACE | grep -q "online-boutique"; then
            DEPLOYMENT_METHOD="helm"
            print_info "Detected Helm deployment"
            return 0
        fi
    fi
    
    # Check if Kustomize deployment exists
    if kubectl get namespace $NAMESPACE &> /dev/null; then
        if kubectl get deployments -n $NAMESPACE | grep -q "frontend"; then
            DEPLOYMENT_METHOD="kubernetes"
            print_info "Detected Kubernetes deployment"
            return 0
        fi
    fi
    
    print_warning "Could not detect deployment method. Using default: $DEPLOYMENT_METHOD"
}

# Function to cleanup Helm deployment
cleanup_helm_deployment() {
    print_info "Cleaning up Helm deployment..."
    
    if command -v helm &> /dev/null; then
        if helm list -n $NAMESPACE | grep -q "online-boutique"; then
            helm uninstall online-boutique -n $NAMESPACE
            print_success "Helm release uninstalled!"
        else
            print_info "No Helm release found."
        fi
    else
        print_warning "Helm not installed. Skipping Helm cleanup."
    fi
}

# Function to cleanup Kubernetes deployment
cleanup_kubernetes_deployment() {
    print_info "Cleaning up Kubernetes deployment..."
    
    # Check if namespace exists
    if ! kubectl get namespace $NAMESPACE &> /dev/null; then
        print_info "Namespace $NAMESPACE not found. Nothing to clean up."
        return 0
    fi
    
    # Delete all resources in the namespace
    print_info "Deleting all resources in namespace $NAMESPACE..."
    
    # Delete deployments
    print_info "Deleting deployments..."
    kubectl delete deployments --all -n $NAMESPACE --timeout=300s || true
    
    # Delete services
    print_info "Deleting services..."
    kubectl delete services --all -n $NAMESPACE --timeout=300s || true
    
    # Delete persistent volume claims
    print_info "Deleting persistent volume claims..."
    kubectl delete pvc --all -n $NAMESPACE --timeout=300s || true
    
    # Delete config maps
    print_info "Deleting config maps..."
    kubectl delete configmaps --all -n $NAMESPACE --timeout=300s || true
    
    # Delete secrets
    print_info "Deleting secrets..."
    kubectl delete secrets --all -n $NAMESPACE --timeout=300s || true
    
    # Delete service accounts
    print_info "Deleting service accounts..."
    kubectl delete serviceaccounts --all -n $NAMESPACE --timeout=300s || true
    
    # Delete roles and role bindings
    print_info "Deleting roles and role bindings..."
    kubectl delete roles --all -n $NAMESPACE --timeout=300s || true
    kubectl delete rolebindings --all -n $NAMESPACE --timeout=300s || true
    
    # Delete the namespace
    print_info "Deleting namespace $NAMESPACE..."
    kubectl delete namespace $NAMESPACE --timeout=300s
    
    print_success "Kubernetes deployment cleaned up!"
}

# Function to cleanup Istio resources
cleanup_istio_resources() {
    print_info "Cleaning up Istio resources..."
    
    # Check if Istio is installed
    if command -v istioctl &> /dev/null; then
        # Delete Istio resources if they exist
        if kubectl get namespace $NAMESPACE &> /dev/null; then
            kubectl delete -f istio-manifests/frontend-gateway.yaml -n $NAMESPACE --ignore-not-found=true
            kubectl delete -f istio-manifests/frontend.yaml -n $NAMESPACE --ignore-not-found=true
            print_success "Istio resources cleaned up!"
        fi
    else
        print_info "Istio not detected. Skipping Istio cleanup."
    fi
}

# Function to cleanup orphaned resources
cleanup_orphaned_resources() {
    print_info "Cleaning up orphaned resources..."
    
    # Clean up any orphaned persistent volumes
    print_info "Cleaning up orphaned persistent volumes..."
    kubectl get pv | grep -v "NAME" | while read name rest; do
        if kubectl get pv $name -o jsonpath='{.spec.claimRef.namespace}' 2>/dev/null | grep -q "$NAMESPACE"; then
            print_info "Deleting orphaned PV: $name"
            kubectl delete pv $name --timeout=60s || true
        fi
    done
    
    # Clean up any orphaned Load Balancers (if using cloud provider)
    print_info "Checking for orphaned Load Balancers..."
    if command -v aws &> /dev/null; then
        # AWS Load Balancer cleanup
        aws elbv2 describe-load-balancers --query 'LoadBalancers[?contains(LoadBalancerName, `online-boutique`) || contains(LoadBalancerName, `boutique`)].LoadBalancerArn' --output text | while read lb_arn; do
            if [ ! -z "$lb_arn" ]; then
                print_info "Deleting orphaned Load Balancer: $lb_arn"
                aws elbv2 delete-load-balancer --load-balancer-arn "$lb_arn" || true
            fi
        done
    fi
    
    print_success "Orphaned resources cleaned up!"
}

# Function to verify cleanup
verify_cleanup() {
    print_info "Verifying cleanup..."
    
    # Check if namespace still exists
    if kubectl get namespace $NAMESPACE &> /dev/null; then
        print_warning "Namespace $NAMESPACE still exists. Manual cleanup may be required."
    else
        print_success "Namespace $NAMESPACE successfully deleted."
    fi
    
    # Check for any remaining resources
    print_info "Checking for remaining resources..."
    
    # Check for any remaining pods
    remaining_pods=$(kubectl get pods --all-namespaces | grep $NAMESPACE || true)
    if [ ! -z "$remaining_pods" ]; then
        print_warning "Remaining pods found:"
        echo "$remaining_pods"
    else
        print_success "No remaining pods found."
    fi
    
    # Check for any remaining services
    remaining_services=$(kubectl get services --all-namespaces | grep $NAMESPACE || true)
    if [ ! -z "$remaining_services" ]; then
        print_warning "Remaining services found:"
        echo "$remaining_services"
    else
        print_success "No remaining services found."
    fi
    
    print_success "Cleanup verification completed!"
}

# Function to display cleanup summary
display_cleanup_summary() {
    echo ""
    echo "=========================================="
    echo "🧹 ONLINE BOUTIQUE CLEANUP COMPLETED"
    echo "=========================================="
    echo ""
    echo "Cleanup completed successfully!"
    echo ""
    echo "Resources removed:"
    echo "------------------"
    echo "✅ Namespace: $NAMESPACE"
    echo "✅ All microservices deployments"
    echo "✅ All services and endpoints"
    echo "✅ All persistent volumes and claims"
    echo "✅ All configuration maps and secrets"
    echo "✅ All RBAC resources"
    echo "✅ Istio resources (if applicable)"
    echo ""
    echo "To redeploy the application, run:"
    echo "./installation/deploy-online-boutique.sh"
    echo ""
}

# Function to show redeployment options
show_redeployment_options() {
    echo ""
    print_info "Redeployment Options"
    echo "======================"
    echo ""
    echo "To redeploy the online boutique:"
    echo ""
    echo "1. Basic deployment:"
    echo "   ./installation/deploy-online-boutique.sh"
    echo ""
    echo "2. With external access:"
    echo "   ./installation/deploy-online-boutique.sh --external-access"
    echo ""
    echo "3. Using Helm:"
    echo "   ./installation/deploy-online-boutique.sh --method helm"
    echo ""
    echo "4. With Istio service mesh:"
    echo "   ./installation/deploy-online-boutique.sh --enable-istio"
    echo ""
    echo "5. Custom namespace:"
    echo "   ./installation/deploy-online-boutique.sh --namespace my-boutique"
    echo ""
}

# Function to parse command line arguments
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --namespace)
                NAMESPACE="$2"
                shift 2
                ;;
            --method)
                DEPLOYMENT_METHOD="$2"
                shift 2
                ;;
            --force)
                FORCE_CLEANUP="true"
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

# Function to show help
show_help() {
    echo "Online Boutique Microservices Cleanup Script"
    echo "============================================"
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --namespace NAME    Namespace to clean up (default: online-boutique)"
    echo "  --method METHOD     Deployment method: kubernetes, helm (default: auto-detect)"
    echo "  --force             Skip confirmation prompt"
    echo "  --help              Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0                                    # Clean up with confirmation"
    echo "  $0 --namespace boutique --force       # Clean up without confirmation"
    echo "  $0 --method helm                      # Clean up Helm deployment"
    echo ""
}

# Main function
main() {
    echo "🧹 Online Boutique Microservices Cleanup"
    echo "========================================"
    echo ""
    echo "This script will remove the complete online boutique application."
    echo ""
    echo "Configuration:"
    echo "- Namespace: $NAMESPACE"
    echo "- Deployment Method: $DEPLOYMENT_METHOD (will auto-detect)"
    echo ""
    
    # Parse command line arguments
    parse_arguments "$@"
    
    # Check prerequisites
    check_prerequisites
    
    # Confirm cleanup (unless --force is used)
    if [ "$FORCE_CLEANUP" != "true" ]; then
        confirm_cleanup
    fi
    
    # Detect deployment method
    detect_deployment_method
    
    # Cleanup based on method
    case $DEPLOYMENT_METHOD in
        "helm")
            cleanup_helm_deployment
            ;;
        "kubernetes")
            cleanup_kubernetes_deployment
            ;;
        *)
            print_error "Unknown deployment method: $DEPLOYMENT_METHOD"
            exit 1
            ;;
    esac
    
    # Cleanup Istio resources
    cleanup_istio_resources
    
    # Cleanup orphaned resources
    cleanup_orphaned_resources
    
    # Verify cleanup
    verify_cleanup
    
    # Display cleanup summary
    display_cleanup_summary
    
    # Show redeployment options
    show_redeployment_options
    
    print_success "🎉 Online Boutique cleanup completed successfully!"
}

# Run main function
main "$@" 