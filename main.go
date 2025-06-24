package main

import (
	"context"
	"fmt"
	"log/slog"
	"net/http"
	"os"
	"os/signal"
	"path/filepath"
	"syscall"
	"time"

	_ "github.com/lib/pq"
	"go.opentelemetry.io/otel"
	"go.opentelemetry.io/otel/exporters/otlp/otlptrace/otlptracehttp"
	"go.opentelemetry.io/otel/propagation"
	"go.opentelemetry.io/otel/sdk/resource"
	sdktrace "go.opentelemetry.io/otel/sdk/trace"
	semconv "go.opentelemetry.io/otel/semconv/v1.21.0"
	"go.opentelemetry.io/otel/trace"
)

var (
	logger *slog.Logger
	tracer trace.Tracer
)

func main() {
	// Initialize logger
	if err := initLogger(); err != nil {
		fmt.Printf("Failed to initialize logger: %v\n", err)
		os.Exit(1)
	}

	logger.Info("Starting Go application", "version", os.Getenv("IMAGE_TAG"))

	// Initialize OpenTelemetry
	if err := initTracing(); err != nil {
		logger.Error("Failed to initialize tracing", "error", err)
		os.Exit(1)
	}

	// Create HTTP server
	mux := http.NewServeMux()
	mux.HandleFunc("/", handleRoot)
	mux.HandleFunc("/health", handleHealth)

	server := &http.Server{
		Addr:    ":3000",
		Handler: mux,
	}

	// Start server in goroutine
	go func() {
		logger.Info("Server starting", "port", 3000)
		if err := server.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			logger.Error("Server failed to start", "error", err)
			os.Exit(1)
		}
	}()

	// Wait for interrupt signal to gracefully shutdown
	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
	<-quit

	logger.Info("Server shutting down")

	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	if err := server.Shutdown(ctx); err != nil {
		logger.Error("Server forced to shutdown", "error", err)
	}

	logger.Info("Server exited")
}

func initLogger() error {
	logPath := os.Getenv("LOG_PATH")
	if logPath == "" {
		logPath = "/tmp/app.log"
	}

	// Create log directory if it doesn't exist
	if err := os.MkdirAll(filepath.Dir(logPath), 0755); err != nil {
		return fmt.Errorf("failed to create log directory: %w", err)
	}

	// Create or open log file
	logFile, err := os.OpenFile(logPath, os.O_CREATE|os.O_WRONLY|os.O_APPEND, 0666)
	if err != nil {
		return fmt.Errorf("failed to open log file: %w", err)
	}

	// Create structured logger that writes to both file and stdout
	logger = slog.New(slog.NewJSONHandler(logFile, &slog.HandlerOptions{
		Level: slog.LevelInfo,
	}))

	// Also log to stdout for development
	stdoutLogger := slog.New(slog.NewTextHandler(os.Stdout, &slog.HandlerOptions{
		Level: slog.LevelInfo,
	}))

	// Use a multi-writer approach
	logger = slog.New(&multiHandler{
		handlers: []slog.Handler{
			logger.Handler(),
			stdoutLogger.Handler(),
		},
	})

	return nil
}

func initTracing() error {
	endpoint := os.Getenv("OTEL_ENDPOINT")
	if endpoint == "" {
		logger.Warn("OTEL_ENDPOINT not set, skipping tracing setup")
		return nil
	}

	exporter, err := otlptracehttp.New(context.Background(),
		otlptracehttp.WithEndpoint(endpoint),
		otlptracehttp.WithInsecure(),
	)
	if err != nil {
		return fmt.Errorf("failed to create trace exporter: %w", err)
	}

	tp := sdktrace.NewTracerProvider(
		sdktrace.WithBatcher(exporter),
		sdktrace.WithResource(resource.NewWithAttributes(
			semconv.SchemaURL,
			semconv.ServiceName("vps-template-example"),
			semconv.ServiceVersion(os.Getenv("IMAGE_TAG")),
		)),
	)

	otel.SetTracerProvider(tp)
	otel.SetTextMapPropagator(propagation.TraceContext{})

	tracer = otel.Tracer("vps-template-example")

	return nil
}

func handleRoot(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	if tracer != nil {
		var span trace.Span
		ctx, span = tracer.Start(r.Context(), "handleRoot")
		defer span.End()
	}

	logger.InfoContext(ctx, "Root endpoint accessed",
		"method", r.Method,
		"path", r.URL.Path,
		"remote_addr", r.RemoteAddr,
		"user_agent", r.UserAgent(),
	)

	html := `<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Go VPS Template</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            display: flex;
            justify-content: center;
            align-items: center;
            height: 100vh;
            margin: 0;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
        }
        .container {
            text-align: center;
            padding: 2rem;
            background: rgba(255, 255, 255, 0.1);
            border-radius: 10px;
            backdrop-filter: blur(10px);
        }
        h1 {
            margin-bottom: 1rem;
            font-size: 2.5rem;
        }
        p {
            font-size: 1.2rem;
            margin: 0.5rem 0;
        }
        .version {
            font-size: 0.9rem;
            opacity: 0.8;
            margin-top: 1rem;
        }
        .links {
            margin-top: 2rem;
        }
        .links a {
            color: #fff;
            text-decoration: none;
            margin: 0 1rem;
            padding: 0.5rem 1rem;
            border: 1px solid rgba(255,255,255,0.3);
            border-radius: 5px;
            transition: background-color 0.3s;
        }
        .links a:hover {
            background-color: rgba(255,255,255,0.2);
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>🚀 Go VPS Template</h1>
        <p>Welcome to your Go application!</p>
        <p>This app demonstrates structured logging, tracing, and database connectivity.</p>
        <div class="version">Version: ` + os.Getenv("IMAGE_TAG") + `</div>
        <div class="links">
            <a href="/health">Health Check</a>
        </div>
    </div>
</body>
</html>`

	w.Header().Set("Content-Type", "text/html")
	w.WriteHeader(http.StatusOK)
	w.Write([]byte(html))
}

func handleHealth(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	if tracer != nil {
		var span trace.Span
		ctx, span = tracer.Start(r.Context(), "handleHealth")
		defer span.End()
	}

	logger.InfoContext(ctx, "Health check accessed")

	health := map[string]string{
		"status":  "healthy",
		"version": os.Getenv("IMAGE_TAG"),
		"time":    time.Now().UTC().Format(time.RFC3339),
	}

	w.Header().Set("Content-Type", "application/json")
	fmt.Fprintf(w, `{"status":"%s","version":"%s","time":"%s"}`,
		health["status"], health["version"], health["time"])
}

// multiHandler allows writing to multiple handlers simultaneously
type multiHandler struct {
	handlers []slog.Handler
}

func (h *multiHandler) Enabled(ctx context.Context, level slog.Level) bool {
	for _, handler := range h.handlers {
		if handler.Enabled(ctx, level) {
			return true
		}
	}
	return false
}

func (h *multiHandler) Handle(ctx context.Context, record slog.Record) error {
	for _, handler := range h.handlers {
		if handler.Enabled(ctx, record.Level) {
			if err := handler.Handle(ctx, record); err != nil {
				return err
			}
		}
	}
	return nil
}

func (h *multiHandler) WithAttrs(attrs []slog.Attr) slog.Handler {
	newHandlers := make([]slog.Handler, len(h.handlers))
	for i, handler := range h.handlers {
		newHandlers[i] = handler.WithAttrs(attrs)
	}
	return &multiHandler{handlers: newHandlers}
}

func (h *multiHandler) WithGroup(name string) slog.Handler {
	newHandlers := make([]slog.Handler, len(h.handlers))
	for i, handler := range h.handlers {
		newHandlers[i] = handler.WithGroup(name)
	}
	return &multiHandler{handlers: newHandlers}
}
