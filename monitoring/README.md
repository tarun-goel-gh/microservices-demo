# Monitoring Stack for Microservices Demo

This directory contains a comprehensive monitoring stack for the microservices-demo application, featuring Prometheus, Mimir, and Grafana for observability and monitoring.

## Architecture Overview

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Microservices │    │   Prometheus    │    │     Mimir       │
│   (ecomm-prod)  │───▶│   (Collection)  │───▶│   (Storage)     │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
         ▼                       ▼                       ▼
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Promtail      │    │   OpenTelemetry │    │     Tempo       │
│   (Logs)        │───▶│   Collector     │───▶│   (Traces)      │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
         ▼                       ▼                       ▼
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│     Loki        │    │    Grafana      │    │  AlertManager   │
│   (Log Storage) │    │ (Visualization) │    │   (Alerts)      │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

## Components

### 1. Prometheus
- **Purpose**: Metrics collection and alerting
- **Version**: v2.45.0
- **Features**:
  - Scrapes metrics from all microservices
  - Kubernetes service discovery
  - Remote write to Mimir for scalable storage
  - Built-in alerting rules

### 2. Mimir
- **Purpose**: Scalable time series storage
- **Version**: v2.10.1
- **Features**:
  - Horizontal scalability
  - Long-term storage
  - Multi-tenancy support
  - Compatible with Prometheus remote write

### 3. Grafana
- **Purpose**: Visualization and dashboards
- **Version**: v10.0.3
- **Features**:
  - Pre-configured dashboards for microservices
  - Multiple data sources (Prometheus, Mimir)
  - Real-time monitoring
  - Customizable alerts

### 4. kube-state-metrics
- **Purpose**: Kubernetes state metrics
- **Version**: v2.8.2
- **Features**:
  - Exposes Kubernetes resource metrics
  - Pod, service, deployment metrics
  - Resource utilization tracking

### 5. node-exporter
- **Purpose**: Node-level metrics
- **Version**: v1.6.1
- **Features**:
  - System metrics (CPU, memory, disk)
  - Network metrics
  - Hardware metrics

### 6. Loki
- **Purpose**: Log aggregation and storage
- **Version**: v2.9.0
- **Features**:
  - Centralized log storage
  - Log querying and filtering
  - Integration with Grafana
  - Scalable log ingestion

### 7. Promtail
- **Purpose**: Log collection agent
- **Version**: v2.9.0
- **Features**:
  - Collects logs from all nodes
  - Kubernetes service discovery
  - Automatic log parsing
  - Sends logs to Loki

### 8. Tempo
- **Purpose**: Distributed tracing storage
- **Version**: v2.3.0
- **Features**:
  - Trace storage and querying
  - Multiple protocol support (Jaeger, OTLP, Zipkin)
  - Integration with Grafana
  - Scalable trace storage

### 9. OpenTelemetry Collector
- **Purpose**: Telemetry data collection
- **Version**: v0.88.0
- **Features**:
  - Collects traces, metrics, and logs
  - Multiple protocol support
  - Data processing and transformation
  - Sends data to Tempo and Prometheus

## Quick Start

### Prerequisites
- Kubernetes cluster (EKS recommended)
- kubectl configured
- Helm (optional, for alternative deployment)

### Deployment

1. **Deploy the monitoring stack:**
   ```bash
   chmod +x deploy-monitoring.sh
   ./deploy-monitoring.sh
   ```

2. **Or deploy as part of the main application:**
   ```bash
   ./deploy-to-aws-eks.sh
   # Choose option 1 when prompted for monitoring stack
   ```

### Access URLs

After deployment, you'll get access to:

- **Grafana**: `http://<loadbalancer-url>:3000`
  - Username: `admin`
  - Password: `admin`

- **Prometheus** (internal): `http://prometheus.monitoring.svc.cluster.local:9090`
- **Mimir** (internal): `http://mimir.monitoring.svc.cluster.local:9009`
- **Loki** (internal): `http://loki.monitoring.svc.cluster.local:3100`
- **Tempo** (internal): `http://tempo.monitoring.svc.cluster.local:3200`
- **OpenTelemetry Collector** (internal): `http://otel-collector.monitoring.svc.cluster.local:4317`

### Port Forwarding (for local access)

```bash
# Grafana
kubectl port-forward -n monitoring svc/grafana 3000:3000

# Prometheus
kubectl port-forward -n monitoring svc/prometheus 9090:9090

# Mimir
kubectl port-forward -n monitoring svc/mimir 9009:9009

# Loki
kubectl port-forward -n monitoring svc/loki 3100:3100

# Tempo
kubectl port-forward -n monitoring svc/tempo 3200:3200

# OpenTelemetry Collector
kubectl port-forward -n monitoring svc/otel-collector 4317:4317
```

## Dashboards

### Microservices Overview Dashboard
- **Service Health**: Real-time status of all microservices
- **Request Rate**: Requests per second for each service
- **Response Time**: 95th percentile response times
- **Error Rate**: Error percentage for each service
- **Resource Usage**: CPU and memory usage by pod
- **Redis Metrics**: Redis connection and memory usage
- **Pod Restarts**: Pod restart frequency

### Complete Observability Dashboard
- **All metrics from above** plus:
- **Log Volume by Service**: Real-time log ingestion from all services
- **Error Logs**: Filtered error logs from all services
- **Trace Latency Distribution**: Distributed tracing latency heatmap
- **Trace Error Rate**: Error rates from distributed traces
- **Correlated Views**: Metrics, logs, and traces in one dashboard

### Key Metrics Monitored

#### Application Metrics
- HTTP request rate and duration
- Error rates and status codes
- Service availability
- Business metrics (cart operations, checkout flow)

#### Infrastructure Metrics
- CPU and memory usage
- Disk I/O and network traffic
- Pod restart frequency
- Kubernetes resource utilization

#### Database Metrics
- Redis connection count
- Memory usage
- Operation latency

#### Log Metrics
- Log volume by service
- Error log frequency
- Log parsing statistics

#### Trace Metrics
- Request latency distribution
- Service dependency mapping
- Error propagation tracking

## Alerting Rules

The monitoring stack includes pre-configured alerting rules:

### Critical Alerts
- **Service Down**: Service not responding
- **High Error Rate**: Error rate > 5%
- **Redis Connection Issues**: Redis not responding

### Warning Alerts
- **High CPU Usage**: CPU > 80%
- **High Memory Usage**: Memory > 85%
- **Pod Restarting Frequently**: > 5 restarts in 15 minutes
- **High Response Time**: 95th percentile > 2 seconds
- **Frontend High Latency**: > 1 second
- **Cart Service High Latency**: > 0.5 seconds

## Configuration

### Prometheus Configuration
- **Scrape Interval**: 15 seconds
- **Retention**: 15 days (local storage)
- **Remote Write**: All metrics sent to Mimir
- **Service Discovery**: Automatic Kubernetes service discovery

### Mimir Configuration
- **Storage**: Filesystem-based (can be changed to S3)
- **Replication**: Single replica (can be scaled)
- **Limits**: Configurable per-user and per-metric limits

### Grafana Configuration
- **Authentication**: Admin/admin (change in production)
- **Data Sources**: Prometheus and Mimir configured
- **Dashboards**: Auto-provisioned microservices dashboard

## Scaling Considerations

### Horizontal Scaling
- **Mimir**: Can be scaled to multiple replicas
- **Prometheus**: Can be federated for large clusters
- **Grafana**: Can be scaled behind a load balancer

### Storage Scaling
- **Local Storage**: Uses EBS volumes (can be changed to EFS)
- **Remote Storage**: Can be configured to use S3 for Mimir
- **Retention**: Configurable retention policies

## Troubleshooting

### Common Issues

1. **Prometheus not scraping metrics**
   ```bash
   kubectl logs -f deployment/prometheus -n monitoring
   kubectl get endpoints -n ecomm-prod
   ```

2. **Grafana not accessible**
   ```bash
   kubectl get service grafana -n monitoring
   kubectl logs -f deployment/grafana -n monitoring
   ```

3. **Mimir not receiving data**
   ```bash
   kubectl logs -f deployment/mimir -n monitoring
   kubectl get pvc -n monitoring
   ```

### Useful Commands

```bash
# Check monitoring stack status
kubectl get pods -n monitoring

# View Prometheus targets
kubectl port-forward -n monitoring svc/prometheus 9090:9090
# Then visit http://localhost:9090/targets

# Check metrics endpoints
kubectl get endpoints -n ecomm-prod

# View Grafana logs
kubectl logs -f deployment/grafana -n monitoring

# Check persistent volumes
kubectl get pvc -n monitoring
```

## Cleanup

To remove the monitoring stack:

```bash
chmod +x cleanup-monitoring.sh
./cleanup-monitoring.sh
```

This will:
- Delete the monitoring namespace
- Remove all persistent volumes
- Clean up cluster roles and bindings
- Remove all monitoring configurations

## Production Considerations

### Security
- Change default Grafana credentials
- Use RBAC for fine-grained access control
- Enable TLS for all communications
- Use secrets for sensitive configuration

### Performance
- Adjust scrape intervals based on load
- Configure appropriate resource limits
- Use dedicated nodes for monitoring
- Consider using managed services (Amazon Managed Grafana, etc.)

### Storage
- Use S3 for long-term storage
- Configure backup and retention policies
- Monitor storage costs
- Use appropriate storage classes

### High Availability
- Deploy multiple replicas of each component
- Use anti-affinity rules
- Configure proper health checks
- Set up monitoring for the monitoring stack itself

## Cost Optimization

### AWS Cost Considerations
- **EBS Volumes**: Monitor storage usage and costs
- **EC2 Instances**: Use appropriate instance types
- **Load Balancers**: Consider using ALB instead of ELB
- **Data Transfer**: Minimize cross-AZ data transfer

### Resource Optimization
- Adjust resource requests and limits
- Use horizontal pod autoscaling
- Monitor and optimize scrape intervals
- Clean up old metrics and logs

## Support

For issues and questions:
1. Check the troubleshooting section above
2. Review the logs of individual components
3. Verify Kubernetes cluster health
4. Check AWS service status and quotas 