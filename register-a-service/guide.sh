# create config directory
mkdir ./consul.d

# create service definition config file

echo '{
  "service": {
    "name": "web",
    "tags": [
      "rails"
    ],
    "port": 80
  }
}' > ./consul.d/web.json

# run consul agent

consul agent -dev -enable-script-checks -config-dir=./consul.d

# You'll notice in the output that Consul "synced" the web service. 
# This means that the agent loaded the service definition from the configuration file, and has successfully registered it in the service catalog.

# check Consul UI -> http://localhost:8500/ui/dc1/services/web/instances


# ----- DNS INTERFACE ------

# The fully-qualified domain name of the web service is web.service.consul. 
# Query the DNS interface (which Consul runs by default on port 8600) for the registered service.
dig @127.0.0.1 -p 8600 web.service.consul

# As you can verify from the output, an A record was returned containing the IP address where the service was registered. A records can only hold IP addresses

# Querying SRV records
dig @127.0.0.1 -p 8600 web.service.consul SRV

# Querying services by tags
dig @127.0.0.1 -p 8600 rails.web.service.consul

# Querying service via HTTP API
curl http://localhost:8500/v1/catalog/service/web

# Update service and register a healthcheck
echo '{
  "service": {
    "name": "web",
    "tags": [
      "rails"
    ],
    "port": 80,
    "check": {
      "args": [
        "curl",
        "localhost"
      ],
      "interval": "10s"
    }
  }
}' > ./consul.d/web.json

# Reload Consul config
consul reload

# Healthcheck for that service will fail because we don't have any running service on port 80

# Run a service on 80/tcp
docker run --name web-nginx  -p 80:80 nginx