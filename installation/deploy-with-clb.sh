#!/bin/bash

# Deploy with Classic Load Balancers Demo Script
# This script demonstrates how to deploy services using Classic Load Balancers

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

# Configuration
NAMESPACE="clb-demo"
LOAD_BALANCER_TYPE="classic"

# Function to check prerequisites
check_prerequisites() {
    print_info "Checking prerequisites..."
    
    if ! command -v kubectl &> /dev/null; then
        print_error "kubectl is not installed"
        exit 1
    fi
    
    if ! kubectl cluster-info &> /dev/null; then
        print_error "Cannot connect to Kubernetes cluster"
        exit 1
    fi
    
    print_success "Prerequisites check passed!"
}

# Function to create namespace
create_namespace() {
    print_info "Creating namespace: $NAMESPACE"
    
    kubectl create namespace $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -
    print_success "Namespace created!"
}

# Function to deploy sample application with CLB
deploy_sample_app() {
    print_info "Deploying sample application with Classic Load Balancer..."
    
    # Create deployment
    cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: sample-app
  namespace: $NAMESPACE
spec:
  replicas: 3
  selector:
    matchLabels:
      app: sample-app
  template:
    metadata:
      labels:
        app: sample-app
    spec:
      containers:
      - name: sample-app
        image: nginx:alpine
        ports:
        - containerPort: 80
        livenessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 5
          periodSeconds: 5
EOF

    # Create service with Classic Load Balancer
    cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: sample-app-service
  namespace: $NAMESPACE
  annotations:
    service.beta.kubernetes.io/aws-load-balancer-type: "$LOAD_BALANCER_TYPE"
    service.beta.kubernetes.io/aws-load-balancer-cross-zone-load-balancing-enabled: "true"
    service.beta.kubernetes.io/aws-load-balancer-connection-idle-timeout: "4000"
    service.beta.kubernetes.io/aws-load-balancer-healthcheck-path: "/"
    service.beta.kubernetes.io/aws-load-balancer-healthcheck-port: "80"
    service.beta.kubernetes.io/aws-load-balancer-healthcheck-protocol: "HTTP"
    service.beta.kubernetes.io/aws-load-balancer-healthcheck-interval: "30"
    service.beta.kubernetes.io/aws-load-balancer-healthcheck-timeout: "5"
    service.beta.kubernetes.io/aws-load-balancer-healthcheck-healthy-threshold: "2"
    service.beta.kubernetes.io/aws-load-balancer-healthcheck-unhealthy-threshold: "2"
spec:
  type: LoadBalancer
  ports:
  - port: 80
    targetPort: 80
    protocol: TCP
  selector:
    app: sample-app
EOF

    print_success "Sample application deployed!"
}

# Function to wait for deployment
wait_for_deployment() {
    print_info "Waiting for deployment to be ready..."
    
    kubectl wait --for=condition=available --timeout=300s deployment/sample-app -n $NAMESPACE
    print_success "Deployment is ready!"
}

# Function to wait for Load Balancer
wait_for_load_balancer() {
    print_info "Waiting for Classic Load Balancer to be provisioned..."
    
    # Wait for Load Balancer to be created
    TIMEOUT=300
    ELAPSED=0
    
    while [ $ELAPSED -lt $TIMEOUT ]; do
        if kubectl get svc sample-app-service -n $NAMESPACE -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' &> /dev/null; then
            print_success "Classic Load Balancer is ready!"
            return 0
        fi
        
        print_info "Waiting for Load Balancer... (${ELAPSED}s elapsed)"
        sleep 10
        ELAPSED=$((ELAPSED + 10))
    done
    
    print_warning "Timeout waiting for Load Balancer"
    return 1
}

# Function to display results
display_results() {
    echo ""
    echo "=========================================="
    echo "🚀 CLASSIC LOAD BALANCER DEMO DEPLOYED!"
    echo "=========================================="
    echo ""
    
    # Get Load Balancer DNS name
    LB_DNS=$(kubectl get svc sample-app-service -n $NAMESPACE -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
    
    if [ ! -z "$LB_DNS" ]; then
        echo "Load Balancer Information:"
        echo "---------------------------"
        echo "DNS Name: $LB_DNS"
        echo "Type: Classic Load Balancer"
        echo "Port: 80"
        echo ""
        echo "Access URLs:"
        echo "------------"
        echo "HTTP: http://$LB_DNS"
        echo ""
        echo "Test Commands:"
        echo "--------------"
        echo "curl -I http://$LB_DNS"
        echo "kubectl get svc -n $NAMESPACE"
        echo "kubectl get pods -n $NAMESPACE"
    else
        echo "Load Balancer is still being provisioned..."
        echo "Check status with: kubectl get svc -n $NAMESPACE"
    fi
    
    echo ""
    echo "Cleanup Commands:"
    echo "-----------------"
    echo "kubectl delete namespace $NAMESPACE"
    echo ""
}

# Function to test connectivity
test_connectivity() {
    print_info "Testing connectivity..."
    
    LB_DNS=$(kubectl get svc sample-app-service -n $NAMESPACE -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
    
    if [ ! -z "$LB_DNS" ]; then
        print_info "Testing HTTP connectivity to $LB_DNS"
        
        if curl -s --max-time 10 -I "http://$LB_DNS" &> /dev/null; then
            print_success "HTTP connectivity test passed!"
        else
            print_warning "HTTP connectivity test failed"
        fi
    else
        print_warning "Load Balancer DNS not available yet"
    fi
}

# Function to show status
show_status() {
    echo ""
    echo "Current Status:"
    echo "==============="
    
    echo ""
    echo "Pods:"
    kubectl get pods -n $NAMESPACE
    
    echo ""
    echo "Services:"
    kubectl get svc -n $NAMESPACE
    
    echo ""
    echo "Load Balancer Details:"
    kubectl describe svc sample-app-service -n $NAMESPACE
}

# Main execution
main() {
    echo "=========================================="
    echo "🚀 Classic Load Balancer Demo"
    echo "=========================================="
    echo ""
    
    check_prerequisites
    create_namespace
    deploy_sample_app
    wait_for_deployment
    wait_for_load_balancer
    test_connectivity
    display_results
    
    echo ""
    print_success "Demo deployment completed!"
    echo ""
    echo "To monitor the deployment:"
    echo "  kubectl get pods -n $NAMESPACE"
    echo "  kubectl get svc -n $NAMESPACE"
    echo ""
    echo "To clean up:"
    echo "  kubectl delete namespace $NAMESPACE"
}

# Run main function
main "$@" 