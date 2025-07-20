# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Online Boutique** is a cloud-first microservices demo application showcasing an e-commerce web app. It consists of 11 microservices written in different languages (Go, Python, Node.js, Java, C#) that communicate via gRPC.

## Architecture

### Microservices Structure
- **frontend** (Go) - HTTP server serving the web interface
- **cartservice** (C#) - Shopping cart storage using Redis/AlloyDB/Spanner
- **productcatalogservice** (Go) - Product catalog and search from JSON
- **currencyservice** (Node.js) - Currency conversion (highest QPS service)
- **paymentservice** (Node.js) - Mock payment processing
- **shippingservice** (Go) - Shipping cost calculation
- **emailservice** (Python) - Order confirmation emails
- **checkoutservice** (Go) - Order orchestration
- **recommendationservice** (Python) - Product recommendations
- **adservice** (Java) - Context-based advertisements
- **loadgenerator** (Python/Locust) - Realistic traffic simulation

### Protocol Buffers
All services use gRPC with Protocol Buffer definitions located in `/protos/demo.proto`.

## Development Commands

### Building and Deployment
Use Skaffold for building and deployment:

```bash
# Build and deploy to local cluster (minikube/kind/docker-desktop)
skaffold run

# Build and deploy with continuous development (auto-rebuild on changes)
skaffold dev

# Deploy to GKE with image registry
skaffold run --default-repo=us-docker.pkg.dev/[PROJECT_ID]/microservices-demo

# Clean up deployed resources
skaffold delete

# Build with Google Cloud Build profile
skaffold run -p gcb --default-repo=us-docker.pkg.dev/[PROJECT_ID]/microservices-demo
```

### Local Development Setup
```bash
# Start local cluster with adequate resources
minikube start --cpus=4 --memory 4096 --disk-size 32g

# Or use Kind
kind create cluster

# Port forward to access frontend locally
kubectl port-forward deployment/frontend 8080:8080
```

### Testing
- No comprehensive test framework is currently configured
- Individual services may have basic tests (check service-specific directories)

## Repository Structure

### `/src/` - Source Code
Each microservice has its own directory with:
- `Dockerfile` for containerization
- Language-specific build files (`go.mod`, `package.json`, `build.gradle`, etc.)
- Service implementation and gRPC handlers

### `/installation/` - AWS EKS Deployment
- `deploy-to-aws-eks.sh` - Complete AWS deployment script
- Monitoring stack deployment scripts
- Cluster management tools and troubleshooting guides

### `/monitoring/` - Observability Stack
Complete monitoring solution with:
- Prometheus (metrics collection)
- Mimir (scalable metrics storage)  
- Loki (log aggregation)
- Tempo (distributed tracing)
- Grafana (visualization)
- OpenTelemetry Collector

### `/release/` - Production Manifests
- `kubernetes-manifests.yaml` - Production-ready Kubernetes manifests
- `istio-manifests.yaml` - Service mesh configuration

### `/kustomize/` - Configuration Variations
- Base configurations in `/kustomize/base/`
- Components for different deployment scenarios (Istio, AlloyDB, Spanner, etc.)

## Key Configuration Files

- `skaffold.yaml` - Build and deployment configuration
- `kubernetes-manifests/` - Individual service Kubernetes manifests
- `helm-chart/` - Helm chart for deployment
- Protocol buffer definitions in `/protos/`

## Development Notes

- Each service can be developed independently
- Use `genproto.sh` scripts in service directories to regenerate Protocol Buffer code
- Services communicate exclusively via gRPC (except frontend HTTP interface)
- OpenTelemetry instrumentation is enabled across services
- Redis is used for cart storage (with AlloyDB/Spanner alternatives available)

## Common Deployment Patterns

- **Basic deployment**: Use `kubernetes-manifests/` 
- **With service mesh**: Use Istio components in `/kustomize/components/service-mesh-istio/`
- **With managed databases**: Use AlloyDB or Spanner components
- **With monitoring**: Deploy observability stack from `/monitoring/`