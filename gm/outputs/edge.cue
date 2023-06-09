// greymatter configuration for Edge

package greymatter

import (
	"list"
)

let egress_to_redis = "\(defaults.edge.key)_egress_to_redis"

let upstream_clusters = list.Concat([
	[defaults.edge.key, egress_to_redis, external_mesh_connections_ingress],
	[ if defaults.edge.oidc.enable_remote_jwks {defaults.edge.oidc.remote_jwks_cluster}],
])

edge_config: [
	// This domain is special because it uses edge certs instead of sidecar certs.  This secures outside -> in traffic
	#domain & {
		domain_key:        defaults.edge.key
		_trust_file:       "/etc/proxy/tls/edge/ca.crt"
		_certificate_path: "/etc/proxy/tls/edge/server.crt"
		_key_path:         "/etc/proxy/tls/edge/server.key"
	},
	#listener & {
		listener_key:                defaults.edge.key
		_gm_observables_topic:       defaults.edge.key
		_is_ingress:                 true
		_enable_oidc_authentication: false
		_enable_rbac:                false
		_enable_fault_injection:     false
		_enable_ext_authz:           false
		_oidc_endpoint:              defaults.edge.oidc.endpoint
		_edge_protocol:              [
						if (_security_spec.edge.type == "tls" || _security_spec.edge.type == "mtls") {"https"},
						if _security_spec.edge.type == "plaintext" {"http"},
		][0]
		_oidc_service_url:   "\(_edge_protocol)://\(defaults.edge.oidc.edge_domain):\(defaults.ports.edge_ingress)"
		_oidc_client_id:     defaults.edge.oidc.client_id
		_oidc_cookie_domain: defaults.edge.oidc.edge_domain
		_oidc_realm:         defaults.edge.oidc.realm
	},
	// This cluster must exist (though it never receives traffic)
	// so that Catalog will be able to look-up edge instances
	#cluster & {
		cluster_key: defaults.edge.key
	},

	// egress -> redis
	#domain & {
		domain_key: egress_to_redis
		port:       defaults.ports.redis_ingress
		// Set to true to force no ssl_config
		// on the plaintext egress listener
		_is_egress: true
	},
	#cluster & {
		cluster_key:  egress_to_redis
		name:         defaults.redis_cluster_name
		_spire_self:  defaults.edge.key
		_spire_other: defaults.redis_cluster_name
	},
	#route & {
		route_key: egress_to_redis
	},
	#listener & {
		listener_key: egress_to_redis
		// egress listeners are local-only
		ip:            "127.0.0.1"
		port:          defaults.ports.redis_ingress
		_tcp_upstream: defaults.redis_cluster_name
	},

	#proxy & {
		proxy_key:     defaults.edge.key
		domain_keys:   upstream_clusters
		listener_keys: upstream_clusters
	},
]
