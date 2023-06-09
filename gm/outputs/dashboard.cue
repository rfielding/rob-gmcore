// greymatter configuration for Dashboard's sidecar

package greymatter

let Name = "dashboard"
let LocalName = "\(Name)_ingress"
let EgressToRedisName = "\(Name)_egress_to_redis"

dashboard_config: [
	// sidecar -> dashboard
	#domain & {
		domain_key: LocalName
	},
	#listener & {
		listener_key:          LocalName
		_spire_self:           Name
		_gm_observables_topic: Name
		_is_ingress:           true
	},
	#cluster & {
		cluster_key:    LocalName
		_upstream_port: 1337
	},
	#route & {
		route_key: LocalName
	},

	// egress -> redis
	#domain & {
		domain_key: EgressToRedisName
		port:       defaults.ports.redis_ingress
		// Set to true to force no ssl_config
		// on the plaintext egress listener
		_is_egress: true
	},
	#cluster & {
		cluster_key:  EgressToRedisName
		name:         defaults.redis_cluster_name
		_spire_self:  Name
		_spire_other: defaults.redis_cluster_name
	},
	// unused route must exist for the cluster to be registered with sidecar
	#route & {
		route_key: EgressToRedisName
	},
	#listener & {
		listener_key: EgressToRedisName
		// egress listeners are local-only
		ip:   "127.0.0.1"
		port: defaults.ports.redis_ingress
		// NB this points at a cluster name, not key
		_tcp_upstream: defaults.redis_cluster_name
	},

	// shared proxy object
	#proxy & {
		proxy_key: Name
		domain_keys: [LocalName, EgressToRedisName]
		listener_keys: [LocalName, EgressToRedisName]
	},

	// edge -> sidecar
	#cluster & {
		cluster_key:  Name
		_spire_other: Name
	},
	#route & {
		domain_key: defaults.edge.key
		route_key:  Name
		// If you want the dashboard to be served from it's own sub-route
		// in the mesh, you can use the following configuration. You may
		// change the "path" and "from" values accordingly to meet your
		// enterprise routing needs.
		// route_match: {
		//     path:       "/dashboard/"
		// }
		// redirects: [
		//     {
		//         from:          "^/dashboard$"
		//         to:            route_match.path
		//         redirect_type: "permanent"
		//     },
		// ]
	},
]
