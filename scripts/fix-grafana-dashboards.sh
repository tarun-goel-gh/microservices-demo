#!/bin/bash

# Fix Grafana Dashboard ConfigMaps
# This script updates the dashboard ConfigMaps with the correct JSON structure

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
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

# Main execution
main() {
    print_status "Starting Grafana dashboard fix..."
    
    # Check if we're in the right directory
    if [ ! -f "monitoring/microservices-dashboard-fixed.json" ]; then
        print_error "Fixed dashboard files not found. Please run this script from the microservices-demo directory."
        exit 1
    fi
    
    # Update microservices dashboard ConfigMap
    print_status "Updating microservices dashboard ConfigMap..."
    kubectl create configmap microservices-dashboard-fixed \
        --from-file=microservices-dashboard.json=monitoring/microservices-dashboard-fixed.json \
        -n monitoring --dry-run=client -o yaml | kubectl apply -f -
    
    if [ $? -eq 0 ]; then
        print_success "Successfully updated microservices dashboard ConfigMap"
    else
        print_error "Failed to update microservices dashboard ConfigMap"
        exit 1
    fi
    
    # Update observability dashboard ConfigMap
    print_status "Updating observability dashboard ConfigMap..."
    kubectl create configmap observability-dashboard-fixed \
        --from-file=observability-dashboard.json=monitoring/observability-dashboard-fixed.json \
        -n monitoring --dry-run=client -o yaml | kubectl apply -f -
    
    if [ $? -eq 0 ]; then
        print_success "Successfully updated observability dashboard ConfigMap"
    else
        print_error "Failed to update observability dashboard ConfigMap"
        exit 1
    fi
    
    # Update Grafana deployment to use the new ConfigMaps
    print_status "Updating Grafana deployment to use fixed dashboards..."
    
    # Create a patch for the Grafana deployment
    cat <<EOF | kubectl patch deployment grafana -n monitoring --patch-file /dev/stdin
spec:
  template:
    spec:
      containers:
      - name: grafana
        volumeMounts:
        - name: microservices-dashboard-fixed
          mountPath: /var/lib/grafana/dashboards/default/microservices-dashboard.json
          subPath: microservices-dashboard.json
        - name: observability-dashboard-fixed
          mountPath: /var/lib/grafana/dashboards/default/observability-dashboard.json
          subPath: observability-dashboard.json
      volumes:
      - name: microservices-dashboard-fixed
        configMap:
          name: microservices-dashboard-fixed
      - name: observability-dashboard-fixed
        configMap:
          name: observability-dashboard-fixed
EOF
    
    if [ $? -eq 0 ]; then
        print_success "Successfully updated Grafana deployment"
    else
        print_error "Failed to update Grafana deployment"
        exit 1
    fi
    
    # Restart Grafana to pick up the new dashboards
    print_status "Restarting Grafana deployment..."
    kubectl rollout restart deployment/grafana -n monitoring
    
    if [ $? -eq 0 ]; then
        print_success "Successfully restarted Grafana deployment"
    else
        print_error "Failed to restart Grafana deployment"
        exit 1
    fi
    
    print_status "Waiting for Grafana to be ready..."
    kubectl rollout status deployment/grafana -n monitoring --timeout=300s
    
    if [ $? -eq 0 ]; then
        print_success "Grafana is ready!"
    else
        print_warning "Grafana deployment may still be in progress"
    fi
    
    print_status "Dashboard fix completed successfully!"
    print_status "You can now access Grafana and the dashboards should load without errors."
}

# Run the main function
main "$@" 