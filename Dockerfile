FROM golang:1.26-alpine AS build
WORKDIR /src
COPY go.mod .
COPY cmd ./cmd
RUN CGO_ENABLED=0 go build -trimpath -ldflags='-s -w' -o /mock-llm-server ./cmd/mock-llm-server

FROM scratch
COPY --from=build /mock-llm-server /mock-llm-server
EXPOSE 8080
USER 65532:65532
ENTRYPOINT ["/mock-llm-server"]
