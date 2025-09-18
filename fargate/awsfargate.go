package awslambda

import (
	"fmt"
	"net/http"
	"net/http/httputil"
	"os"
	"strings"

	"github.com/nitrictech/suga/runtime/service"
)

type awsfargateService struct{}

func (a *awsfargateService) Start(proxy service.Proxy) error {
	fmt.Println("Starting Fargate service proxy")
	containerPort := "9001"

	stackId := os.Getenv("SUGA_STACK_ID")
	if stackId == "" {
		return fmt.Errorf("SUGA_STACK_ID is not set")
	}

	serviceName := os.Getenv("SUGA_SERVICE_NAME")
	if serviceName == "" {
		return fmt.Errorf("SUGA_SERVICE_NAME is not set")
	}

	servicePrefix := fmt.Sprintf("/%s-%s", stackId, serviceName)
	fmt.Printf("Service prefix: %s\n", servicePrefix)

	p := &httputil.ReverseProxy{
		Director: func(req *http.Request) {
			originalPath := req.URL.Path
			fmt.Printf("Original request path: %s\n", originalPath)

			// Strip the service prefix if present
			if strings.HasPrefix(req.URL.Path, servicePrefix) {
				req.URL.Path = strings.TrimPrefix(req.URL.Path, servicePrefix)
				// Ensure path starts with /
				if !strings.HasPrefix(req.URL.Path, "/") {
					req.URL.Path = "/" + req.URL.Path
				}
			}

			fmt.Printf("Forwarding to: %s\n", req.URL.Path)
			req.URL.Host = proxy.Host()
			req.URL.Scheme = "http"
		},
	}

	mux := http.NewServeMux()

	// Health check handler with prefix
	healthPath := servicePrefix + "/x-suga-health"
	mux.HandleFunc(healthPath, func(w http.ResponseWriter, r *http.Request) {
		fmt.Println("Received Health check at", healthPath)
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusOK)
		w.Write([]byte(`{"status":"healthy"}`))
	})

	// Catch-all handler for service requests
	mux.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		// Only handle requests with our service prefix
		if strings.HasPrefix(r.URL.Path, servicePrefix) {
			p.ServeHTTP(w, r)
		} else {
			http.NotFound(w, r)
		}
	})

	fmt.Println("Starting Fargate service proxy on port", containerPort)
	return http.ListenAndServe(fmt.Sprintf(":%s", containerPort), mux)
}

func Plugin() (service.Service, error) {
	return &awsfargateService{}, nil
}
