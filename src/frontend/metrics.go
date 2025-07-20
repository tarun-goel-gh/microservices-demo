package main

import (
	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promauto"
	"github.com/prometheus/client_golang/prometheus/promhttp"
	"net/http"
	"time"
)

var (
	// HTTP request metrics
	httpRequestsTotal = promauto.NewCounterVec(
		prometheus.CounterOpts{
			Name: "http_requests_total",
			Help: "Total number of HTTP requests",
		},
		[]string{"method", "path", "status", "service"},
	)

	httpRequestDuration = promauto.NewHistogramVec(
		prometheus.HistogramOpts{
			Name:    "http_request_duration_seconds",
			Help:    "HTTP request duration in seconds",
			Buckets: prometheus.DefBuckets,
		},
		[]string{"method", "path", "service"},
	)

	// Business metrics
	ordersTotal = promauto.NewCounterVec(
		prometheus.CounterOpts{
			Name: "orders_total",
			Help: "Total number of orders",
		},
		[]string{"status", "service"},
	)

	cartCreatedTotal = promauto.NewCounterVec(
		prometheus.CounterOpts{
			Name: "cart_created_total",
			Help: "Total number of carts created",
		},
		[]string{"service"},
	)

	cartAbandonedTotal = promauto.NewCounterVec(
		prometheus.CounterOpts{
			Name: "cart_abandoned_total",
			Help: "Total number of carts abandoned",
		},
		[]string{"service"},
	)

	paymentAttemptedTotal = promauto.NewCounterVec(
		prometheus.CounterOpts{
			Name: "payment_attempted_total",
			Help: "Total number of payment attempts",
		},
		[]string{"service"},
	)

	paymentFailedTotal = promauto.NewCounterVec(
		prometheus.CounterOpts{
			Name: "payment_failed_total",
			Help: "Total number of failed payments",
		},
		[]string{"service", "reason"},
	)

	// Database metrics
	databaseConnectionsTotal = promauto.NewGaugeVec(
		prometheus.GaugeOpts{
			Name: "database_connections_total",
			Help: "Total number of database connections",
		},
		[]string{"service", "status"},
	)

	databaseConnectionsFailedTotal = promauto.NewCounterVec(
		prometheus.CounterOpts{
			Name: "database_connections_failed_total",
			Help: "Total number of failed database connections",
		},
		[]string{"service", "error"},
	)

	// Cache metrics
	cacheHitsTotal = promauto.NewCounterVec(
		prometheus.CounterOpts{
			Name: "cache_hits_total",
			Help: "Total number of cache hits",
		},
		[]string{"service", "cache_type"},
	)

	cacheMissesTotal = promauto.NewCounterVec(
		prometheus.CounterOpts{
			Name: "cache_misses_total",
			Help: "Total number of cache misses",
		},
		[]string{"service", "cache_type"},
	)

	// Application health metrics
	applicationHealth = promauto.NewGaugeVec(
		prometheus.GaugeOpts{
			Name: "application_health",
			Help: "Application health status (1 = healthy, 0 = unhealthy)",
		},
		[]string{"service", "component"},
	)
)

// initMetrics initializes Prometheus metrics
func initMetrics() {
	// Register metrics with Prometheus
	prometheus.MustRegister(
		httpRequestsTotal,
		httpRequestDuration,
		ordersTotal,
		cartCreatedTotal,
		cartAbandonedTotal,
		paymentAttemptedTotal,
		paymentFailedTotal,
		databaseConnectionsTotal,
		databaseConnectionsFailedTotal,
		cacheHitsTotal,
		cacheMissesTotal,
		applicationHealth,
	)
}

// metricsMiddleware adds Prometheus metrics to HTTP handlers
func metricsMiddleware(handler http.HandlerFunc, serviceName string) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		start := time.Now()
		
		// Create response writer wrapper
		wrappedWriter := &responseWriter{ResponseWriter: w, statusCode: 200}
		
		// Call original handler
		handler(wrappedWriter, r)
		
		// Record metrics
		duration := time.Since(start).Seconds()
		
		// Increment request counter
		httpRequestsTotal.WithLabelValues(
			r.Method,
			r.URL.Path,
			string(wrappedWriter.statusCode),
			serviceName,
		).Inc()
		
		// Record request duration
		httpRequestDuration.WithLabelValues(
			r.Method,
			r.URL.Path,
			serviceName,
		).Observe(duration)
	}
}

// recordOrder records order metrics
func recordOrder(status string) {
	ordersTotal.WithLabelValues(status, "frontend").Inc()
}

// recordCartCreated records cart creation metrics
func recordCartCreated() {
	cartCreatedTotal.WithLabelValues("frontend").Inc()
}

// recordCartAbandoned records cart abandonment metrics
func recordCartAbandoned() {
	cartAbandonedTotal.WithLabelValues("frontend").Inc()
}

// recordPaymentAttempt records payment attempt metrics
func recordPaymentAttempt() {
	paymentAttemptedTotal.WithLabelValues("frontend").Inc()
}

// recordPaymentFailure records payment failure metrics
func recordPaymentFailure(reason string) {
	paymentFailedTotal.WithLabelValues("frontend", reason).Inc()
}

// recordDatabaseConnection records database connection metrics
func recordDatabaseConnection(status string) {
	databaseConnectionsTotal.WithLabelValues("frontend", status).Inc()
}

// recordDatabaseConnectionFailure records database connection failure metrics
func recordDatabaseConnectionFailure(error string) {
	databaseConnectionsFailedTotal.WithLabelValues("frontend", error).Inc()
}

// recordCacheHit records cache hit metrics
func recordCacheHit(cacheType string) {
	cacheHitsTotal.WithLabelValues("frontend", cacheType).Inc()
}

// recordCacheMiss records cache miss metrics
func recordCacheMiss(cacheType string) {
	cacheMissesTotal.WithLabelValues("frontend", cacheType).Inc()
}

// setApplicationHealth sets application health status
func setApplicationHealth(component string, healthy bool) {
	value := 0.0
	if healthy {
		value = 1.0
	}
	applicationHealth.WithLabelValues("frontend", component).Set(value)
}

// setupMetricsEndpoint sets up the /metrics endpoint
func setupMetricsEndpoint() {
	http.Handle("/metrics", promhttp.Handler())
} 