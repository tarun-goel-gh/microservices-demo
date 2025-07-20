# Performance Testing with K6

This directory contains comprehensive performance testing scripts for the microservices-demo application using K6.

## 🎯 **Overview**

The testing suite includes:
- **Catalog Service Tests**: Product listing, search, and details
- **Cart Service Tests**: Cart operations (add, remove, update, clear)
- **Comprehensive Load Tests**: Combined testing of all services
- **Multiple Test Scenarios**: Smoke, load, stress, spike, and endurance tests

## 📁 **Directory Structure**

```
testing/
├── k6/
│   ├── README.md                    # This file
│   ├── catalog-service-test.js      # Catalog service specific tests
│   ├── cart-service-test.js         # Cart service specific tests
│   ├── load-test-runner.js          # Comprehensive test runner
│   ├── k6-config.json              # Test configurations
│   ├── run-tests.sh                # Test execution script
│   └── results/                    # Test results (created automatically)
```

## 🚀 **Quick Start**

### Prerequisites

1. **Install K6**:
   ```bash
   # macOS
   brew install k6
   
   # Ubuntu/Debian
   sudo apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys C5AD17C747E3415A3642D57D77C6C491D6AC1D69
   echo 'deb https://dl.k6.io/deb stable main' | sudo tee /etc/apt/sources.list.d/k6.list
   sudo apt-get update
   sudo apt-get install k6
   
   # Docker
   docker pull grafana/k6
   
   # Windows
   choco install k6
   ```

2. **Deploy the application**:
   ```bash
   # Deploy to AWS EKS
   ./installation/deploy-to-aws-eks.sh
   
   # Or deploy locally
   kubectl apply -f release/kubernetes-manifests.yaml
   ```

### Running Tests

#### 1. **Quick Smoke Test** (2 minutes)
```bash
cd testing/k6
./run-tests.sh -t smoke -u http://localhost:8080
```

#### 2. **Catalog Service Test** (16 minutes)
```bash
./run-tests.sh -t catalog -u http://localhost:8080
```

#### 3. **Cart Service Test** (16 minutes)
```bash
./run-tests.sh -t cart -u http://localhost:8080
```

#### 4. **Comprehensive Load Test** (13 minutes)
```bash
./run-tests.sh -t comprehensive -u http://localhost:8080
```

#### 5. **Stress Test** (15 minutes)
```bash
./run-tests.sh -t stress -u http://localhost:8080
```

## 📊 **Test Types**

### **Smoke Test** (2 minutes)
- **Purpose**: Quick verification of basic functionality
- **Load**: 2 virtual users
- **Duration**: 2 minutes
- **Use Case**: Pre-deployment verification

### **Load Test** (10 minutes)
- **Purpose**: Standard performance testing
- **Load**: 10-20 virtual users
- **Duration**: 10 minutes
- **Use Case**: Regular performance validation

### **Stress Test** (15 minutes)
- **Purpose**: Find system breaking point
- **Load**: 10-50 virtual users
- **Duration**: 15 minutes
- **Use Case**: Capacity planning

### **Spike Test** (5 minutes)
- **Purpose**: Test system behavior under sudden load
- **Load**: 10-50 virtual users (spikes)
- **Duration**: 5 minutes
- **Use Case**: Traffic spike handling

### **Endurance Test** (30 minutes)
- **Purpose**: Long-running stability test
- **Load**: 5 virtual users
- **Duration**: 30 minutes
- **Use Case**: Memory leak detection

### **Service-Specific Tests**

#### **Catalog Service Test** (16 minutes)
- **Endpoints Tested**:
  - `GET /api/products` - Get all products
  - `GET /api/products/{id}` - Get product by ID
  - `GET /api/products/search?q={term}` - Search products
  - `GET /api/products/categories` - Get categories
  - `GET /api/products/category/{category}` - Get products by category

#### **Cart Service Test** (16 minutes)
- **Endpoints Tested**:
  - `GET /api/cart/{userId}` - Get cart
  - `POST /api/cart/{userId}/items` - Add item to cart
  - `PUT /api/cart/{userId}/items/{productId}` - Update item quantity
  - `DELETE /api/cart/{userId}/items/{productId}` - Remove item
  - `GET /api/cart/{userId}/total` - Get cart total
  - `DELETE /api/cart/{userId}/items` - Clear cart

## 🔧 **Configuration**

### **Environment Variables**

- `BASE_URL`: Base URL of the application (default: http://localhost:8080)

### **Test Data**

The tests use predefined test data:
- **Product IDs**: 10 different product IDs
- **User IDs**: 10 different user IDs
- **Search Terms**: 10 different search terms

### **Performance Thresholds**

- **Response Time**: 95% of requests should be below 500ms
- **Error Rate**: Less than 10% error rate
- **Service-Specific Thresholds**:
  - Catalog service: 200-400ms for different operations
  - Cart service: 200-400ms for different operations

## 📈 **Output Formats**

### **JSON Output** (Default)
```bash
./run-tests.sh -t load -o json
```
- Human-readable format
- Easy to parse programmatically
- Good for local analysis

### **InfluxDB Output**
```bash
./run-tests.sh -t load -o influxdb
```
- Time-series format
- Integrates with Grafana
- Good for historical analysis

### **CloudWatch Output**
```bash
./run-tests.sh -t load -o cloudwatch
```
- AWS CloudWatch format
- Integrates with AWS monitoring
- Good for AWS deployments

### **Datadog Output**
```bash
./run-tests.sh -t load -o datadog
```
- Datadog format
- Integrates with Datadog monitoring
- Good for Datadog users

## 🎯 **Test Scenarios**

### **Realistic User Behavior**

The tests simulate realistic user behavior:
- **Random Delays**: 1-3 seconds between requests
- **Random Data**: Random product IDs, user IDs, and search terms
- **Sequential Operations**: Logical flow of operations (e.g., add to cart → view cart → update quantity)
- **Occasional Actions**: Some operations happen occasionally (e.g., clearing cart)

### **Load Distribution**

- **Catalog Service**: 40% of requests
- **Cart Service**: 40% of requests
- **Frontend Service**: 20% of requests

## 📊 **Metrics Collected**

### **Built-in K6 Metrics**
- `http_req_duration`: Request duration
- `http_req_failed`: Failed request rate
- `http_reqs`: Total requests per second
- `http_req_blocked`: Blocked request time
- `http_req_connecting`: Connection time
- `http_req_tls_handshaking`: TLS handshake time
- `http_req_sending`: Request sending time
- `http_req_waiting`: Server processing time
- `http_req_receiving`: Response receiving time

### **Custom Metrics**
- `catalog_response_time`: Catalog service response time
- `product_search_time`: Product search response time
- `product_detail_time`: Product detail response time
- `cart_response_time`: Cart service response time
- `add_item_time`: Add item to cart time
- `get_cart_time`: Get cart time
- `remove_item_time`: Remove item time
- `clear_cart_time`: Clear cart time
- `successful_requests`: Count of successful requests
- `failed_requests`: Count of failed requests
- `errors`: Error rate

## 🔍 **Analyzing Results**

### **JSON Results**
```bash
# View results
cat results/k6_load_20231201_143022.json

# Parse with jq
cat results/k6_load_20231201_143022.json | jq '.metrics.http_req_duration'
```

### **Key Metrics to Monitor**

1. **Response Time Percentiles**:
   - P50 (median): Should be < 200ms
   - P95: Should be < 500ms
   - P99: Should be < 1000ms

2. **Error Rate**:
   - Should be < 10% for load tests
   - Should be < 5% for smoke tests

3. **Throughput**:
   - Requests per second (RPS)
   - Should increase with load until saturation

4. **Resource Utilization**:
   - CPU usage
   - Memory usage
   - Network I/O

## 🚨 **Troubleshooting**

### **Common Issues**

1. **K6 Not Installed**:
   ```bash
   # Check installation
   k6 version
   
   # Install if missing
   brew install k6  # macOS
   ```

2. **Application Not Accessible**:
   ```bash
   # Check if application is running
   curl -I http://localhost:8080
   
   # Check Kubernetes pods
   kubectl get pods -n ecomm-prod
   ```

3. **High Error Rate**:
   - Check application logs
   - Verify service endpoints
   - Check resource constraints

4. **Slow Response Times**:
   - Check CPU and memory usage
   - Verify database performance
   - Check network latency

### **Debug Mode**

Run tests with verbose output:
```bash
k6 run --verbose catalog-service-test.js
```

### **Docker Mode**

Run K6 in Docker:
```bash
docker run -i --rm -v $(pwd):/app -w /app grafana/k6 run catalog-service-test.js
```

## 🔄 **Continuous Testing**

### **CI/CD Integration**

Add to your CI/CD pipeline:
```yaml
# GitHub Actions example
- name: Run Performance Tests
  run: |
    cd testing/k6
    ./run-tests.sh -t smoke -u ${{ env.APP_URL }}
```

### **Scheduled Testing**

Set up cron jobs for regular testing:
```bash
# Daily load test at 2 AM
0 2 * * * cd /path/to/microservices-demo/testing/k6 && ./run-tests.sh -t load -u http://myapp.com
```

## 📚 **Advanced Usage**

### **Custom Test Scenarios**

Create custom test scenarios by modifying the test files:
```javascript
// Add custom metrics
const customMetric = new Trend('custom_metric');

// Add custom checks
check(response, {
  'custom check': (r) => r.status === 200 && r.json('data').length > 0,
});
```

### **Integration with Monitoring**

Send results to monitoring systems:
```bash
# Send to InfluxDB
./run-tests.sh -t load -o influxdb

# Send to CloudWatch
./run-tests.sh -t load -o cloudwatch
```

### **Performance Baselines**

Establish performance baselines:
```bash
# Run baseline test
./run-tests.sh -t load -u http://baseline-app.com

# Compare with current
./run-tests.sh -t load -u http://current-app.com
```

## 🎉 **Summary**

This testing suite provides:
- ✅ **Comprehensive Coverage**: All major services tested
- ✅ **Realistic Scenarios**: Simulates real user behavior
- ✅ **Multiple Test Types**: From smoke to stress testing
- ✅ **Flexible Configuration**: Easy to customize and extend
- ✅ **Rich Metrics**: Detailed performance insights
- ✅ **Easy Integration**: Works with CI/CD and monitoring systems

Use these tests to ensure your microservices application performs well under various load conditions and to identify performance bottlenecks before they affect users. 