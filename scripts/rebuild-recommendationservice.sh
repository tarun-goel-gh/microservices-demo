#!/bin/bash

# Rebuild RecommendationService with Fixed Dockerfile
# This script rebuilds the recommendationservice using a simplified Dockerfile

set -e  # Exit on any error

# Configuration
DOCKER_USERNAME="tarungoel797"
DOCKER_PASSWORD="Na!sha@2014"
REGISTRY="docker.io"
TAG="latest"
SERVICE_NAME="recommendationservice"
DOCKERFILE_PATH="src/recommendationservice/Dockerfile.fixed"
CONTEXT_PATH="src/recommendationservice"

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
    print_status "Starting rebuild for $SERVICE_NAME with fixed Dockerfile..."
    print_status "Docker Hub Username: $DOCKER_USERNAME"
    print_status "Registry: $REGISTRY"
    print_status "Tag: $TAG"
    print_status "Platforms: linux/amd64, linux/arm64"
    
    # Login to Docker Hub
    print_status "Logging in to Docker Hub..."
    echo "$DOCKER_PASSWORD" | docker login -u "$DOCKER_USERNAME" --password-stdin
    
    if [ $? -ne 0 ]; then
        print_error "Failed to login to Docker Hub"
        exit 1
    fi
    
    print_success "Successfully logged in to Docker Hub"
    
    # Build and push the image for multiple architectures
    print_status "Building $SERVICE_NAME with fixed Dockerfile..."
    print_status "Dockerfile: $DOCKERFILE_PATH"
    print_status "Context: $CONTEXT_PATH"
    
    docker buildx build \
        --platform=linux/amd64,linux/arm64 \
        -t "$DOCKER_USERNAME/$SERVICE_NAME:$TAG" \
        -f "$DOCKERFILE_PATH" \
        "$CONTEXT_PATH" \
        --push
    
    if [ $? -eq 0 ]; then
        print_success "Successfully built and pushed $SERVICE_NAME with fixed Dockerfile!"
        print_status "Image: $DOCKER_USERNAME/$SERVICE_NAME:$TAG"
        print_status "Supported architectures: linux/amd64, linux/arm64"
    else
        print_error "Failed to build $SERVICE_NAME"
        exit 1
    fi
    
    # Logout from Docker Hub
    print_status "Logging out from Docker Hub..."
    docker logout
    print_success "Logged out from Docker Hub"
    
    print_status "Rebuild completed successfully!"
}

# Run the main function
main "$@" 