FROM golang:1.12.7-alpine3.10 as build-step

RUN apk add --update --no-cache ca-certificates git

RUN mkdir /go-app
WORKDIR /go-app
COPY go.mod .
# COPY go.sum .

RUN go mod download
COPY . .

RUN CGO_ENABLED=0 go build -o /go/bin/heartful-app


FROM scratch
COPY --from=build-step /go/bin/heartful-app /go/bin/heartful-app
ENTRYPOINT ["/go/bin/heartful-app"]
