# Build stage
FROM golang:1.21-alpine AS builder

ARG IMAGE_TAG=unknown
ENV IMAGE_TAG=${IMAGE_TAG}

WORKDIR /app

# Copy go mod and sum files
COPY go.mod go.sum ./

# Download dependencies
RUN go mod download

# Copy source code
COPY main.go ./

# Build the application
RUN CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -o main .

# Final stage
FROM alpine:latest

ARG IMAGE_TAG=unknown
ENV IMAGE_TAG=${IMAGE_TAG}

# Install ca-certificates for HTTPS requests and curl for health checks
RUN apk --no-cache add ca-certificates curl

WORKDIR /root/

# Copy the binary from builder stage
COPY --from=builder /app/main .

# Create directory for logs
RUN mkdir -p /tmp/app-logs

EXPOSE 3000

CMD ["./main"]
