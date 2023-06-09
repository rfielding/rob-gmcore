package greymatter

let EdgeToKeycloakName = defaults.edge.oidc.remote_jwks_cluster

remote_jwks_config: [
	#domain & {
		domain_key: EdgeToKeycloakName
		port:       defaults.edge.oidc.remote_jwks_egress_port
	},
	#cluster & {
		cluster_key:    EdgeToKeycloakName
		_upstream_host: defaults.edge.oidc.upstream_host
		_upstream_port: defaults.edge.oidc.upstream_port
		ssl_config: {
			protocols: [ "TLS_AUTO"]
			sni:        defaults.edge.oidc.upstream_host
			trust_file: ""
		}
		require_tls: true
	},
	#route & {
		route_key: EdgeToKeycloakName
	},
	#listener & {
		listener_key: EdgeToKeycloakName
		port:         defaults.edge.oidc.remote_jwks_egress_port
	},
]
