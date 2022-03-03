# Install Envoy
curl -L https://func-e.io/install.sh | bash -s -- -b /usr/local/bin
func-e use 1.18.3
sudo cp ~/.func-e/versions/1.18.3/bin/envoy /usr/local/bin/
envoy --version

# Verify agent health
consul members

# Create counting service definition

echo 'service {
  name = "counting"
  id = "counting-1"
  port = 9003

  connect {
    sidecar_service {}
  }

  check {
    id       = "counting-check"
    http     = "http://localhost:9003/health"
    method   = "GET"
    interval = "1s"
    timeout  = "1s"
  }
}' > counting.hcl

# Create dashboard service definition

echo 'service {
  name = "dashboard"
  port = 9002

  connect {
    sidecar_service {
      proxy {
        upstreams = [
          {
            destination_name = "counting"
            local_bind_port  = 5000
          }
        ]
      }
    }
  }

  check {
    id       = "dashboard-check"
    http     = "http://localhost:9002/health"
    method   = "GET"
    interval = "1s"
    timeout  = "1s"
  }
}' > dashboard.hcl

# Note that the dashboard definition also includes an upstream block. Upstreams are ports on the local 
# host that will be proxied to the destination service. The upstream block's local_bind_port value is the port your service will 
# communicate with to reach the service you depend on. The destination name is the Consul service name that the local_bind_port will proxy to.

# Register the services
consul services register counting.hcl
consul services register dashboard.hcl

# Verify services are registered
consul catalog services

# Create Consul Intention

echo 'Kind = "service-intentions"
Name = "counting"
Sources = [
  {
    Name   = "dashboard"
    Action = "allow"
  }
]' > intention-config.hcl

# Intentions define authorization policies for services in the service mesh and are used to control which services may establish connections. 
# The default intention behavior is defined by the default ACL policy.

# Initialize Intention Rules
consul config write intention-config.hcl

# Start the services and sidecar proxies

# Establish the local URL and start the dashboard service.
PORT=9002 COUNTING_SERVICE_URL="http://localhost:5000" ./dashboard-service &

# Start the counting service.
PORT=9003 ./counting-service &

# Next, start the sidecar proxies that will run as sidecar processes along with the service applications.

# Start the Envoy sidecar proxy for the counting service.
consul connect envoy -sidecar-for counting-1 -admin-bind localhost:19001 > counting-proxy.log &

# Start the Envoy sidecar proxy for the dashboard service.
consul connect envoy -sidecar-for dashboard > dashboard-proxy.log &

# Note: The -sidecar-for argument takes a Consul service ID, not a service name.

# Open a browser and navigate to http://localhost:9002.