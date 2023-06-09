// greymatter configuration for Control API's sidecar (inside the controlensemble pod)

package greymatter

let Name = "controlensemble"
let ControlAPIIngressName = "\(Name)_ingress_to_controlapi"
let EgressToRedisName = "\(Name)_egress_to_redis"

controlensemble_config: [

	// Control API HTTP ingress
	#domain & {
		domain_key: ControlAPIIngressName
	},
	#listener & {
		listener_key:          ControlAPIIngressName
		_spire_self:           Name
		_gm_observables_topic: Name
		_is_ingress:           true
	},
	#cluster & {
		cluster_key:    ControlAPIIngressName
		_upstream_port: 5555
	},
	#route & {
		route_key: ControlAPIIngressName
	},

	// egress->redis
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
		ip:            "127.0.0.1"
		port:          defaults.ports.redis_ingress
		_tcp_upstream: defaults.redis_cluster_name
	},

	// shared proxy object
	#proxy & {
		proxy_key: Name
		domain_keys: [ControlAPIIngressName, EgressToRedisName]
		listener_keys: [ControlAPIIngressName, EgressToRedisName]
	},

	// Edge config for Control API
	#cluster & {
		cluster_key:  Name
		_spire_other: Name
	},
	#route & {
		domain_key: defaults.edge.key
		route_key:  Name
		route_match: {
			path: "/services/control-api/"
		}
		redirects: [
			{
				from:          "^/services/control-api$"
				to:            route_match.path
				redirect_type: "permanent"
			},
		]
		prefix_rewrite: "/"
	},
]
