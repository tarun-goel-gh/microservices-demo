package main

import (
	"context"
	"errors"
	"fmt"
	"log"
	"net/http"
	"os"
	"time"

	"go.opentelemetry.io/otel"
	"go.opentelemetry.io/otel/attribute"
	"go.opentelemetry.io/otel/exporters/otlp/otlptrace/otlptracegrpc"
	"go.opentelemetry.io/otel/sdk/resource"
	sdktrace "go.opentelemetry.io/otel/sdk/trace"
	semconv "go.opentelemetry.io/otel/semconv/v1.17.0"
	"go.opentelemetry.io/otel/trace"
	"google.golang.org/grpc/codes"
	"database/sql"
)

var tracer trace.Tracer

// initTracer initializes OpenTelemetry tracer
func initTracer() {
	ctx := context.Background()

	// Create OTLP exporter
	exporter, err := otlptracegrpc.New(ctx, otlptracegrpc.WithEndpoint("otel-collector:4317"))
	if err != nil {
		log.Fatal(err)
	}

	// Create resource with service information
	res, err := resource.New(ctx,
		resource.WithAttributes(
			semconv.ServiceName("frontend"),
			semconv.ServiceVersion("1.0.0"),
			attribute.String("environment", "production"),
		),
	)
	if err != nil {
		log.Fatal(err)
	}

	// Create trace provider
	tp := sdktrace.NewTracerProvider(
		sdktrace.WithBatcher(exporter),
		sdktrace.WithResource(res),
	)

	// Set global trace provider
	otel.SetTracerProvider(tp)

	// Create tracer
	tracer = tp.Tracer("frontend")
}

// instrumentedHandler wraps HTTP handlers with tracing
func instrumentedHandler(handler http.HandlerFunc, operationName string) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		ctx := r.Context()
		
		// Create span
		ctx, span := tracer.Start(ctx, operationName,
			trace.WithAttributes(
				attribute.String("http.method", r.Method),
				attribute.String("http.url", r.URL.String()),
				attribute.String("http.user_agent", r.UserAgent()),
				attribute.String("http.remote_addr", r.RemoteAddr),
			),
		)
		defer span.End()

		// Add trace context to request
		r = r.WithContext(ctx)

		// Create response writer wrapper to capture status code
		wrappedWriter := &responseWriter{ResponseWriter: w, statusCode: 200}
		
		// Call original handler
		handler(wrappedWriter, r)

		// Record response attributes
		span.SetAttributes(
			attribute.Int("http.status_code", wrappedWriter.statusCode),
		)

		// Record error if status code indicates error
		if wrappedWriter.statusCode >= 400 {
			span.RecordError(errors.New("HTTP error"))
		}
	}
}

// responseWriter wraps http.ResponseWriter to capture status code
type responseWriter struct {
	http.ResponseWriter
	statusCode int
}

func (rw *responseWriter) WriteHeader(code int) {
	rw.statusCode = code
	rw.ResponseWriter.WriteHeader(code)
}

// instrumentedHTTPClient creates an HTTP client with tracing
func instrumentedHTTPClient() *http.Client {
	return &http.Client{
		Transport: &tracingTransport{
			base: http.DefaultTransport,
		},
		Timeout: 30 * time.Second,
	}
}

// tracingTransport wraps HTTP transport with tracing
type tracingTransport struct {
	base http.RoundTripper
}

func (t *tracingTransport) RoundTrip(req *http.Request) (*http.Response, error) {
	ctx := req.Context()
	
	// Create span for HTTP request
	ctx, span := tracer.Start(ctx, "http.request",
		trace.WithAttributes(
			attribute.String("http.method", req.Method),
			attribute.String("http.url", req.URL.String()),
			attribute.String("http.target", req.URL.Path),
			attribute.String("http.host", req.URL.Host),
		),
	)
	defer span.End()

	// Add trace context to request
	req = req.WithContext(ctx)

	// Make request
	resp, err := t.base.RoundTrip(req)
	if err != nil {
		span.RecordError(err)
		return nil, err
	}

	// Record response attributes
	span.SetAttributes(
		attribute.Int("http.status_code", resp.StatusCode),
		attribute.String("http.status_text", resp.Status),
	)

	return resp, nil
}

// instrumentedDatabase creates a database client with tracing
func instrumentedDatabase() *DatabaseClient {
	return &DatabaseClient{
		tracer: tracer,
	}
}

// DatabaseClient wraps database operations with tracing
type DatabaseClient struct {
	tracer trace.Tracer
}

func (db *DatabaseClient) Query(ctx context.Context, query string, args ...interface{}) (*sql.Rows, error) {
	ctx, span := db.tracer.Start(ctx, "database.query",
		trace.WithAttributes(
			attribute.String("db.statement", query),
			attribute.String("db.system", "postgresql"),
		),
	)
	defer span.End()

	// Execute query (placeholder)
	// rows, err := db.conn.QueryContext(ctx, query, args...)
	
	// For now, return nil to avoid compilation errors
	return nil, nil
}

// instrumentedCache creates a cache client with tracing
func instrumentedCache() *CacheClient {
	return &CacheClient{
		tracer: tracer,
	}
}

// CacheClient wraps cache operations with tracing
type CacheClient struct {
	tracer trace.Tracer
}

func (c *CacheClient) Get(ctx context.Context, key string) (interface{}, error) {
	ctx, span := c.tracer.Start(ctx, "cache.get",
		trace.WithAttributes(
			attribute.String("cache.key", key),
			attribute.String("cache.system", "redis"),
		),
	)
	defer span.End()

	// Get from cache (placeholder)
	// value, err := c.client.Get(ctx, key).Result()
	
	// For now, return nil to avoid compilation errors
	return nil, nil
}

func (c *CacheClient) Set(ctx context.Context, key string, value interface{}, expiration time.Duration) error {
	ctx, span := c.tracer.Start(ctx, "cache.set",
		trace.WithAttributes(
			attribute.String("cache.key", key),
			attribute.String("cache.system", "redis"),
			attribute.Int64("cache.expiration_ms", int64(expiration.Milliseconds())),
		),
	)
	defer span.End()

	// Set in cache (placeholder)
	// err := c.client.Set(ctx, key, value, expiration).Err()
	
	// For now, return nil to avoid compilation errors
	return nil
}

// metricsMiddleware adds Prometheus metrics to HTTP handlers
func metricsMiddleware(handler http.HandlerFunc) http.HandlerFunc {
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
		).Inc()
		
		// Record request duration
		httpRequestDuration.WithLabelValues(
			r.Method,
			r.URL.Path,
		).Observe(duration)
	}
}

// structuredLogger creates a structured logger with tracing context
func structuredLogger(ctx context.Context) *log.Logger {
	span := trace.SpanFromContext(ctx)
	
	return log.New(os.Stdout, "", log.LstdFlags)
}

// logRequest logs HTTP requests with structured logging
func logRequest(ctx context.Context, r *http.Request, statusCode int, duration time.Duration) {
	logger := structuredLogger(ctx)
	
	logger.Printf("HTTP Request: method=%s path=%s status=%d duration=%v remote_addr=%s user_agent=%s",
		r.Method,
		r.URL.Path,
		statusCode,
		duration,
		r.RemoteAddr,
		r.UserAgent(),
	)
}

// logError logs errors with structured logging and tracing
func logError(ctx context.Context, err error, message string, fields map[string]interface{}) {
	logger := structuredLogger(ctx)
	
	// Build log message
	logMsg := message
	if err != nil {
		logMsg += ": " + err.Error()
	}
	
	// Add fields
	for key, value := range fields {
		logMsg += " " + key + "=" + fmt.Sprintf("%v", value)
	}
	
	logger.Printf("ERROR: %s", logMsg)
	
	// Record error in span
	span := trace.SpanFromContext(ctx)
	span.RecordError(err)
	span.SetStatus(codes.Error, message)
} 