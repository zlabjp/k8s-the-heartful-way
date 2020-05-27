FROM golang:1.12

RUN mkdir /go-app
WORKDIR /go-app
COPY go.mod .
# COPY go.sum .

RUN go mod download
COPY . .

RUN CGO_ENABLED=0 go build -o /go/bin/heartful-app

ENTRYPOINT ["/go/bin/heartful-app"]
