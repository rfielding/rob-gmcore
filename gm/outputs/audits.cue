package greymatter

import (
	"strings"
)

// Name needs to match the greymatter.io/cluster value in the Kubernetes deployment
let Name = "audits"
let AuditsAppIngressName = "\(Name)_ingress"
let EgressToRedisName = "\(Name)_egress_to_redis"
let EgressToElasticSearchName = "\(Name)_egress_to_elasticsearch"

audits_config: [

	// HTTP ingress
	#domain & {
		domain_key: AuditsAppIngressName
	},
	#listener & {
		listener_key:          AuditsAppIngressName
		_spire_self:           Name
		_gm_observables_topic: Name
		_is_ingress:           true
	},
	#cluster & {
		cluster_key:    AuditsAppIngressName
		_upstream_port: 5000
	},
	#route & {
		route_key: AuditsAppIngressName
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
		ip:            "127.0.0.1"
		port:          defaults.ports.redis_ingress
		_tcp_upstream: defaults.redis_cluster_name
	},

	// egress -> elasticsearch
	#domain & {
		domain_key: EgressToElasticSearchName
		// don't change this, the app expects this port
		port: 9200
		// Set to true to force no ssl_config
		// on the plaintext egress listener
		_is_egress: true
	},
	#cluster & {
		cluster_key:    EgressToElasticSearchName
		name:           "elasticsearch"
		require_tls:    true
		_upstream_host: defaults.audits.elasticsearch_host
		_upstream_port: defaults.audits.elasticsearch_port
	},
	// unused route must exist for the cluster to be registered with sidecar
	#route & {
		route_key: EgressToElasticSearchName
	},
	#listener & {
		listener_key: EgressToElasticSearchName
		// egress listeners are local-only
		ip: "127.0.0.1"
		// don't change this, the app expects this port
		port: 9200
	},

	// shared proxy object
	#proxy & {
		proxy_key: Name
		domain_keys: [AuditsAppIngressName, EgressToRedisName, EgressToElasticSearchName]
		listener_keys: [AuditsAppIngressName, EgressToRedisName, EgressToElasticSearchName]
	},

	// Config for greymatter.io edge ingress.
	#cluster & {
		cluster_key:  Name
		_spire_other: Name
	},
	#route & {
		domain_key: "edge"
		route_key:  Name
		route_match: {
			path: "/services/audits/"
		}
		redirects: [
			{
				from:          "^/services/audits$"
				to:            route_match.path
				redirect_type: "permanent"
			},
		]
		prefix_rewrite: "/"
	},

	// Config for edge ingress to support mesh-segmentation.
	#route & {
		domain_key:            defaults.edge.key
		route_key:             "\(Name)_edge_plus"
		_upstream_cluster_key: Name
		route_match: {
			path: "/services/audits/"
		}
		redirects: [
			{
				from:          "^/services/audits$"
				to:            route_match.path
				redirect_type: "permanent"
			},
		]
		prefix_rewrite: "/"
	},

	// greymatter Catalog service entry.
	#catalog_entry & {
		name:                      "Audits"
		owner:                     "greymatter.io"
		mesh_id:                   mesh.metadata.name
		service_id:                "\(Name)"
		version:                   strings.Split(defaults.images.audits, ":")[1]
		description:               "A standalone dashboard visualizing data collected from greymatter audits."
		api_endpoint:              "/services/audits"
		business_impact:           "critical"
		enable_instance_metrics:   true
		enable_historical_metrics: config.enable_historical_metrics
		capability:                "Mesh"
	},
]
