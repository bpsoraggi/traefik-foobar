FROM golang:1.21-alpine AS builder

RUN apk add --no-cache git
WORKDIR /app

COPY app/go.mod app/go.sum ./
RUN go mod download

COPY app/ .
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -o foobar-api \
    -ldflags="-s -w" app.go

FROM alpine:3.18
WORKDIR /

RUN addgroup -S appgroup && adduser -S appuser -G appgroup \
    && mkdir /cert && chown appuser:appgroup /cert

COPY --from=builder /app/foobar-api /usr/local/bin/foobar-api

USER appuser
EXPOSE 80
ENTRYPOINT ["/usr/local/bin/foobar-api"]