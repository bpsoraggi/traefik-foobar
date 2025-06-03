ARG GO_VERSION=1.23
# FROM golang:${GO_VERSION}-bookworm AS builder
FROM golang:${GO_VERSION}-alpine AS builder
# RUN apk add --no-cache ca-certificates git

RUN apk add --no-cache git
WORKDIR /app

COPY app/go.mod app/go.sum ./
RUN go mod download

COPY app/ .
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -o foobar-api \
    -ldflags="-s -w" app.go

FROM gcr.io/distroless/base-debian11:nonroot
WORKDIR /

COPY --from=builder /app/foobar-api /usr/local/bin/foobar-api

EXPOSE 80
ENTRYPOINT ["/usr/local/bin/foobar-api"]
