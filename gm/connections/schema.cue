package greymatter

import (
	api "greymatter.io/api"
	"regexp"
	"crypto/md5"
	"encoding/hex"
	"strings"
	"strconv"
)

let external_mesh_connections_egress = "catalog_egress_for_connections"

// Root schema. Must be present in the connections.cue file
#Connections: {
	outbound_socket: #Outbound
	inbound_socket:  #Inbound
	connections: [Name=string]: #Connection & {name: Name}
	accept_connections: *false | bool

	// If any connection is TLS, add a custom header informing envoy to upgrade the connection.
	for c in connections {
		if c.tls != _|_ {
			outbound_socket: domain: custom_headers: [
				{
					key:   "x-forwarded-proto"
					value: "https"
				},
			]
		}
	}

}

#AcceptConnections: accept_connections: true

// A route-cluster combo. Holds the config for the destination catalog
#Connection: {
	url:        string
	public_url: string
	N=name:     string
	T=tls?:     #OutboundTLSConfig
	// name could potentially be unsafe for a url. A simple fix in CUE is to hash and truncate since the url is not human-facing
	url_safe_name: strings.SliceRunes(hex.Encode(md5.Sum(name)), 0, 8)
	route:         #route & {
		_upstream_cluster_key: "\(name)-cluster"
		domain_key:            external_mesh_connections_egress
		route_key:             "\(name)-route"
		prefix_rewrite:        "/"
		route_match: {
			path: "/\(url_safe_name)/"
		}
		redirects: [
			{
				from:          "^/\(url_safe_name)$"
				to:            route_match.path
				redirect_type: "permanent"
			},
		]
	}
	cluster: #cluster & {
		zone_key:    string | *"default-zone"
		name:        N
		cluster_key: "\(name)-cluster"
		if T != _|_ {
			T
		}

		instances: [{
			host: _host
			port: _port
		}]
	}

	// Processing the url into parts we can use
	_scheme:       *regexp.FindSubmatch(#"(\w+)://"#, url)[1] | "http"
	_port_default: int
	if _scheme == "https" {
		_port_default: 443
	}
	if _scheme == "http" {
		_port_default: 80
	}
	_host: regexp.FindSubmatch(#"//([\w\d-.]+)"#, url)[1]
	_port: *strconv.Atoi(regexp.FindSubmatch(#":(\d+$)"#, url)[1]) | _port_default
}

// Ingress traffic tls configuration.
// This gets applied to the downstream listener on the edge.
#InboundTLSConfig: {
	force_https: *true | bool
	ssl_config:  api.#ListenerSSLConfig & {
		protocols: [ "TLS_AUTO"]
		require_client_certs:      bool | *true
		allow_expired_certificate: bool | *false
		cert_key_pairs: [
			api.#CertKeyPathPair & {
				certificate_path: string | *"/etc/proxy/tls/edge/connections/server.crt"
				key_path:         string | *"/etc/proxy/tls/edge/connections/server.key"
			},
		]
		trust_file: string | *"/etc/proxy/tls/edge/connections/ca.crt"
	}
}

// Egress traffic TLS configuration. 
// This gets applied to a cluster upstream on the catalog
// sidecar.
#OutboundTLSConfig: {
	require_tls: *true | bool
	ssl_config:  api.#ClusterSSLConfig & {
		protocols: [ "TLS_AUTO"]
		cert_key_pairs: [
			api.#CertKeyPathPair & {
				certificate_path: string | *"/etc/proxy/tls/sidecar/connections/server.crt"
				key_path:         string | *"/etc/proxy/tls/sidecar/connections/server.key"
			},
		]
		trust_file: string | *"/etc/proxy/tls/sidecar/connections/ca.crt"
	}
}

// Listener, domain, & route rule on the edge to the catalog sidecar
// We connect into the existing edge-catalog cluster 
#Inbound: {
	tls?:   #InboundTLSConfig
	domain: #domain & {
		if tls != _|_ {
			tls
		}

		domain_key: external_mesh_connections_ingress
		port:       10710
	}
	listener: #listener & {
		listener_key:          external_mesh_connections_ingress
		_gm_observables_topic: external_mesh_connections_ingress
		ip:                    "0.0.0.0"
		port:                  10710
		_is_ingress:           true
	}
	route: #route & {
		_upstream_cluster_key: "catalog"
		domain_key:            external_mesh_connections_ingress
		route_key:             "mesh-connections-edge-ingress"
		route_match: {
			path: "/services/catalog/"
		}
		redirects: [
			{
				from:          "^/services/catalog$"
				to:            route_match.path
				redirect_type: "permanent"
			},
		]
		prefix_rewrite: "/"
	}
}

// Egress listener for the catalog sidecar
#Outbound: {
	domain: #domain & {
		domain_key: external_mesh_connections_egress
		port:       10610
		// Set to true to force no ssl_config
		// on plaintext egress traffic
		_is_egress: true
	}
	listener: #listener & {
		listener_key:          external_mesh_connections_egress
		_gm_observables_topic: external_mesh_connections_egress
		ip:                    "127.0.0.1"
		port:                  10610
	}
}
