package main

import (
	"fmt"
	"net"
	"net/http"
)

func handler(w http.ResponseWriter, r *http.Request) {
	addrs, _ := net.InterfaceAddrs()
	fmt.Fprintln(w, "# The Heartful Way")
	fmt.Fprintln(w, "")

	fmt.Fprintln(w, "## Local Address")
	for _, addr := range addrs {
		if ipnet, ok := addr.(*net.IPNet); ok && !ipnet.IP.IsLoopback() {
			if ipnet.IP.To4() != nil {
				fmt.Fprintln(w, ipnet.IP.String())
			}
		}
	}
	fmt.Fprintln(w, "")

	fmt.Fprintln(w, "## Remote Address")
	fmt.Fprintln(w, r.RemoteAddr)
	fmt.Fprintln(w, "")

	fmt.Fprintln(w, "## Request Host")
	fmt.Fprintln(w, r.Host)
}

func main() {
	http.HandleFunc("/", handler)
	http.ListenAndServe(":8080", nil)
}
