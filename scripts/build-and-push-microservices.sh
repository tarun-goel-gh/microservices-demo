#!/bin/bash

# Microservices Demo - Build and Push to Docker Hub
# Username: tarungoel797
# This script builds and pushes all microservices to Docker Hub

set -e  # Exit on any error

# Configuration
DOCKER_USERNAME="tarungoel797"
DOCKER_PASSWORD="Na!sha@2014"
REGISTRY="docker.io"
TAG="latest"

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

# Function to build and push a service
build_and_push_service() {
    local service_name=$1
    local dockerfile_path=$2
    local context_path=$3
    
    print_status "Building $service_name..."
    
    # Build the image for multiple architectures using buildx
    docker buildx build --platform=linux/amd64,linux/arm64 -t "$DOCKER_USERNAME/$service_name:$TAG" -f "$dockerfile_path" "$context_path" --push
    
    if [ $? -eq 0 ]; then
        print_success "Successfully built and pushed $service_name for multiple architectures"
    else
        print_error "Failed to build $service_name"
        return 1
    fi
}

# Main execution
main() {
    print_status "Starting build and push process for all microservices..."
    print_status "Docker Hub Username: $DOCKER_USERNAME"
    print_status "Registry: $REGISTRY"
    print_status "Tag: $TAG"
    
    # Login to Docker Hub
    print_status "Logging in to Docker Hub..."
    echo "$DOCKER_PASSWORD" | docker login -u "$DOCKER_USERNAME" --password-stdin
    
    if [ $? -ne 0 ]; then
        print_error "Failed to login to Docker Hub"
        exit 1
    fi
    
    print_success "Successfully logged in to Docker Hub"
    
    # Define services with their Dockerfile paths and context
    services=(
        "frontend:src/frontend/Dockerfile:src/frontend"
        "adservice:src/adservice/Dockerfile:src/adservice"
        "cartservice:src/cartservice/src/Dockerfile:src/cartservice/src"
        "checkoutservice:src/checkoutservice/Dockerfile:src/checkoutservice"
        "currencyservice:src/currencyservice/Dockerfile:src/currencyservice"
        "emailservice:src/emailservice/Dockerfile:src/emailservice"
        "loadgenerator:src/loadgenerator/Dockerfile:src/loadgenerator"
        "paymentservice:src/paymentservice/Dockerfile:src/paymentservice"
        "productcatalogservice:src/productcatalogservice/Dockerfile:src/productcatalogservice"
        "recommendationservice:src/recommendationservice/Dockerfile:src/recommendationservice"
        "shippingservice:src/shippingservice/Dockerfile:src/shippingservice"
        "shoppingassistantservice:src/shoppingassistantservice/Dockerfile:src/shoppingassistantservice"
    )
    
    # Build and push each service
    failed_services=()
    
    for service_info in "${services[@]}"; do
        IFS=':' read -r service_name dockerfile_path context_path <<< "$service_info"
        
        print_status "Processing $service_name..."
        print_status "Dockerfile: $dockerfile_path"
        print_status "Context: $context_path"
        
        if build_and_push_service "$service_name" "$dockerfile_path" "$context_path"; then
            print_success "Completed $service_name"
        else
            print_error "Failed to process $service_name"
            failed_services+=("$service_name")
        fi
        
        echo "----------------------------------------"
    done
    
    # Summary
    echo ""
    print_status "Build and push process completed!"
    
    if [ ${#failed_services[@]} -eq 0 ]; then
        print_success "All services were successfully built and pushed!"
        print_status "You can now deploy using the following image references:"
        echo ""
        for service_info in "${services[@]}"; do
            IFS=':' read -r service_name dockerfile_path context_path <<< "$service_info"
            echo "  $service_name: $DOCKER_USERNAME/$service_name:$TAG"
        done
    else
        print_warning "Some services failed to build or push:"
        for service in "${failed_services[@]}"; do
            print_error "  - $service"
        done
        print_status "Please check the errors above and retry the failed services."
    fi
    
    # Logout from Docker Hub
    print_status "Logging out from Docker Hub..."
    docker logout
    print_success "Logged out from Docker Hub"
}

# Run the main function
main "$@" 