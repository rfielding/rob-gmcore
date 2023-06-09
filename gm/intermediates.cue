package greymatter

import (
	"list"

	greymatter "greymatter.io/api"
	httpFilters "greymatter.io/api/filters/http:http"
	rbac "envoyproxy.io/extensions/filters/http/rbac/v3"
	ratelimit "envoyproxy.io/extensions/filters/network/ratelimit/v3"
	jwt_authn "envoyproxy.io/extensions/filters/http/jwt_authn/v3"
	fault "envoyproxy.io/extensions/filters/http/fault/v3"
	ext_authz "envoyproxy.io/extensions/filters/http/ext_authz/v3"
	ext_authz_tcp "envoyproxy.io/extensions/filters/network/ext_authz/v3"
	lua "envoyproxy.io/extensions/filters/http/lua/v3"
)

/////////////////////////////////////////////////////////////
// "Functions" for greymatter.io config objects with defaults
// reflecting common local service configuration. All of which
// can be overriden.
/////////////////////////////////////////////////////////////

// external_mesh_connections_ingress is the key used for greymatter mesh objects
// for inbound connections from external meshes.
external_mesh_connections_ingress: "edge_ingress_for_connections"

// #domain represents a greymatter domain object, which deals with incoming 
// requests to the service.
// See https://docs.greymatter.io/service-mesh/domain for more details.
#domain: greymatter.#Domain & {
	// Set _force_https to true to turn on secure traffic to the service.
	// For edge services that want TLS, this should be enabled
	_force_https: bool | *false
	// Set _require_client_certs for TLS enabled sidecars to require
	// x.509 client certificates during the TLS handshake. For web browsers,
	// the user will need to load their certificate into their browser or
	// computer's certificate storage.
	_require_client_certs: bool | *false
	// Identifers for the domain object within the mesh
	domain_key: string
	name:       string | *"*"
	// Port to access the service on
	port: int | *defaults.ports.default_ingress
	// Designates which zone the object belongs to
	zone_key: mesh.spec.zone
	// Configures TLS settings for incoming requests, utilizing 
	// mounted certificates to allow for HTTPS traffic
	_trust_file:       string | *"/etc/proxy/tls/sidecar/ca.crt"
	_certificate_path: string | *"/etc/proxy/tls/sidecar/server.crt"
	_key_path:         string | *"/etc/proxy/tls/sidecar/server.key"

	_force_no_ssl: bool | *false
	_is_egress:    bool | *false

	_enable_ssl_block: [
				if (domain_key != defaults.edge.key && domain_key != external_mesh_connections_ingress && (_security_spec.internal.type == "manual-tls" || _security_spec.internal.type == "manual-mtls")) {true},
				if (domain_key == defaults.edge.key && (_security_spec.edge.type == "tls" || _security_spec.edge.type == "mtls" )) {true},
				if _security_spec.internal.type == "plaintext" {false},
				if _security_spec.internal.type == "spire" {false},
				false,
	][0]

	if _enable_ssl_block && (!_force_no_ssl) && (!_is_egress) {
		if domain_key != defaults.edge.key {
			_require_client_certs: [
						if _security_spec.internal.type == "manual-tls" {false},
						if _security_spec.internal.type == "manual-mtls" {true},
						false,
			][0]
		}
		if domain_key == defaults.edge.key {
			_require_client_certs: [
						if _security_spec.edge.type == "tls" {false},
						if _security_spec.edge.type == "mtls" {true},
						false,
			][0]
		}

		force_https: true
		ssl_config:  greymatter.#SSLConfig & {
			// Specify a TLS Protocol to use when communicating
			// Supported options are:
			// TLS_AUTO TLSv1_0 TLSv1_1 TLSv1_2 TLSv1_3
			protocols: [ "TLS_AUTO"]
			// TLS certificate defaults, if enabled.
			// These paths are created via volume mounts to the container
			// That we specify in the k8s manifests for the service.
			// If these files are mounted in a different location, change
			// these paths.
			if _require_client_certs {
				trust_file: _trust_file
			}
			cert_key_pairs: [
				greymatter.#CertKeyPathPair & {
					certificate_path: _certificate_path
					key_path:         _key_path
				},
			]
			require_client_certs: _require_client_certs
		}
	}
}

// #listener represents a greymatter listener object, which provide avenues to 
// receive traffic for the proxy. They have filters which can act based on
// incoming requests. 
// See https://docs.greymatter.io/service-mesh/listener for more details.
#listener: greymatter.#Listener & {
	// For TCP listeners, you can just specify the upstream cluster
	_tcp_upstream?: string
	// Specifiy if this listener is for ingress, which will activate default HTTP filters
	_is_ingress: bool | *false
	// This should be enabled if a listener will be proxying redis. The filter ordering
	// requirements special treatment with this upstream.
	_is_redis: bool | *false
	// Unique topic name for observable audit collection
	// See https://docs.greymatter.io/filters/observables for more details.
	_gm_observables_topic: string

	// These options are for configuring traffic that utilizes
	// SPIFFE/SPIRE for automatic mTLS protection.
	// Can specify current identity
	// Set by default to the name of the service.    
	_spire_self: string
	// Can specify an allowable downstream identity
	// Set by default to the name of the service.      
	_spire_other: string

	// These toggles enable filters for use with a service.
	// Each toggle provides a default config that can be overridden
	// in the CUE file for a service. Note that some toggles may 
	// activate more than one filter, such as OIDC.
	// More information about each filter can be found with their
	// configuration within the network_filters or http_filters section.
	_enable_rbac:                bool | *false
	_enable_fault_injection:     bool | *false
	_enable_oidc_authentication: bool | *false
	// Inheaders and impersonation require mTLS at the edge and inside the mesh.
	_enable_inheaders:     bool | *false
	_enable_impersonation: bool | *false
	// For TCP rate limiting, you must include a service->rate limiter service cluster using HTTP/2
	_enable_tcp_rate_limit: bool | *false
	// For external authorization you must create a service->ext authz service cluster. 
	// If auth server is grpc, HTTP/2 only
	_enable_ext_authz: bool | *false

	// Enables the jwt-security filter. Must have a mesh with jwt-security running.
	// Typically will be used in conjunction with PKI authentication, inheaders, impersonation. 
	// Should not be used with OIDC. 
	_enable_jwt_security: bool | *false

	// Set of configurable values for use in OIDC configurations
	// and populated by inputs.cue if applicable.
	// Do not change theses values in the service, rather make 
	// the change within inputs.cue
	_oidc_endpoint:      string
	_oidc_service_url:   string
	_oidc_client_id:     string
	_oidc_cookie_domain: string
	_oidc_realm:         string

	_keycloak_pre_17: bool | *false
	if defaults.edge.oidc.keycloak_pre_17 != _|_ {
		_keycloak_pre_17: defaults.edge.oidc.keycloak_pre_17
	}

	protocol: *"http_auto" | "tcp"
	if _tcp_upstream != _|_ {
		protocol: "tcp"
	}

	// Identifiers for the object within the mesh
	listener_key: string
	name:         listener_key
	// IP and port that the listener should process requests for
	ip:   string | *"0.0.0.0"
	port: int | *defaults.ports.default_ingress
	// List of domains for this listener to be attached to.
	// Change this in your service if you have more than one
	// domain, or if you use a different string for your domain
	// and listener keys.
	domain_keys: [...string] | *[listener_key]

	// External filters secrets are utilized by Control to 
	// map secretive information read from the environment
	// into a filters configuration.
	_external_filter_secrets: {
		...
	}

	// To override default weights insert this CUE expression into the #listener block of the service:
	// _http_filter_weight: "<name of the filter>": <new value>
	// Example: _http_filter_weight: "envoy.lua": 9000

	// To add a weight other than the default weight of 5 for a filter not found in this map:
	// _http_filter_weight: "<name of the filter>": <value>

	// _http_filter_weight holds default weights for filter sorting positions
	_http_filter_weight: {
		// Authentication always comes first so we can 
		// block/deny/allow as necessary.
		"envoy.lua":              *1 | int
		"envoy.fault":            *1 | int
		"gm.inheaders":           *1 | int
		"gm.impersonation":       *1 | int
		"gm.oidc-authentication": *1 | int
		"gm.ensure-variables":    *1 | int
		"gm.oidc-validation":     *1 | int

		// the greymatter observability pipeline
		// comes in the middle of the filter stack
		// so we can collect stats.
		"gm.observables": *2 | int

		// This kind of auth needs to be tracked by the 
		// observability pipeline.
		"envoy.jwt_authn": *3 | int
		"envoy.ext_authz": *3 | int
		"envoy.rbac":      *3 | int

		// Metrics is last due to a known 
		// cardinality issue that may overload the system.
		"gm.metrics": *10 | int
		...
	}

	// _network_filter_weight holds default weights for filter sorting positions
	// see above comments on how to override these values
	_network_filter_weight: {
		// Authentication always comes first so we can 
		// block/deny/allow as necessary.
		"envoy.ext_authz": *1 | int

		// Rate limiting also receives a high priority
		// since it can prevent DOS attacks.
		"envoy.rate_limit": *2 | int

		// TCP proxy and protocol filters should 
		// always be last as they signal the proxy 
		// what kind of connection its handling.
		"envoy.tcp_proxy": *10 | int

		// The greymatter proxy requires redis to be 
		// last in the network filter chain.
		"envoy.redis_proxy": *11 | int
		...
	}

	// For TCP listeners.
	if _tcp_upstream != _|_ {
		_active_network_filter_toggles: [
			if _enable_ext_authz {
				"envoy.ext_authz"
			},
			if _enable_tcp_rate_limit {
				"envoy.rate_limit"
			},
			// Needs to be last in filter chain
			"envoy.tcp_proxy",
			if _is_redis {
				"envoy.redis_proxy"
			},
			...string,
		]

		// Users input custom filters through this API.
		// It is different than the active_network_filters list which is what 
		// is sent to control-api through JSON. This list gets unified with the 
		// known mapping list and gets a middle weight assigned to all its 
		// values.
		_active_network_filters: [
			...string,
		]

		// This active_network_filters list contains the filters which will be active on the listener.
		// NB: Even if configuration exists in network_filters for a filter,
		// only filters which are listed as active will be applied and used.
		// The sort order is determined by the weights found in _network_filter_weights
		// list.Sort is stable. 
		active_network_filters: list.Sort(
					// the inputted array is the combined user defined filters and our
					// known list of toggleable filters.
					_active_network_filter_toggles+_active_network_filters,
					// Filters without a weight receive a default weight of 5
					{x: string, y: string, less: (*_network_filter_weight[x] | 5) < (*_network_filter_weight[y] | 5)},
					)

		network_filters: {
			// Configures rate limiting for TCP listeners.
			// See #envoy_tcp_rate_limit below for the default 
			// configuration and more detail on using this filter.
			// Also see the envoy docs for more information:
			// https://www.envoyproxy.io/docs/envoy/v1.16.5/configuration/listeners/network_filters/rate_limit_filter
			if _enable_tcp_rate_limit {
				envoy_rate_limit: #envoy_tcp_rate_limit
			}

			// Allows for external authorization of requests.
			// See the envoy docs for more information:
			// https://www.envoyproxy.io/docs/envoy/v1.16.5/configuration/listeners/network_filters/ext_authz_filter
			if _enable_ext_authz {
				envoy_ext_authz: #envoy_tcp_ext_authz // See XXX for default values
			}
			envoy_tcp_proxy: {
				// NB: contrary to the docs, this points at a cluster *name*, not a cluster_key
				cluster:     _tcp_upstream
				stat_prefix: _tcp_upstream
			}
		}
	}

	// Non-TCP listeners that are ingress can have HTTP filters applied to them
	if _tcp_upstream == _|_ && _is_ingress == true {
		_active_http_filter_toggles: [
			if _enable_fault_injection {
				"envoy.fault"
			},
			// Note: Inheaders and impersonation only function when mTLS is active
			// throughout the mesh, via Spire or another means. Also, gm.inheaders
			// and gm.impersonation generally aren't set on the same proxy.
			if _enable_inheaders {
				"gm.inheaders"
			},
			if _enable_impersonation {
				"gm.impersonation"
			},
			// Note that only one filter can be added per conditional expression.
			// These four filters allow the OIDC authentication flow to facilitate
			// additional policies like RBAC.
			if _enable_oidc_authentication {
				"gm.oidc-authentication"
			},
			if _enable_oidc_authentication {
				"gm.ensure-variables"
			},
			if _enable_oidc_authentication {
				"gm.oidc-validation"
			},
			if _enable_oidc_authentication {
				"envoy.lua"
			},
			// This filter is essential to the operation of the mesh and should
			// not be disabled.
			"gm.observables",
			if _enable_oidc_authentication {
				"envoy.jwt_authn"
			},
			if _enable_ext_authz {
				"envoy.ext_authz"
			},
			if _enable_rbac {
				"envoy.rbac"
			},
			// This filter is essential to the operation of the mesh and should
			// not be disabled.
			"gm.metrics",
		]

		// Users input custom filters through this API.
		// It is different than the active_http_filters list which is what 
		// is sent to control-api. This list gets unified with the 
		// known mapping list and gets a middle weight assigned to all its 
		// values.
		_active_http_filters: [
			...string,
		]

		// The active_http_filters list contains the filters which will be active on the listener.
		// NB: Even if configuration exists in http_filters for a filter,
		// only filters which are listed as active will be applied and used.
		// The sort order is determined by the weights found in _http_filter_weights
		// list.Sort is stable. 
		active_http_filters: list.Sort(
					// the inputted array is the combined user defined filters and our
					// known list of toggleable filters.
					_active_http_filter_toggles+_active_http_filters,
					// Filters without a weight receive a default weight of 5
					{x: string, y: string, less: (*_http_filter_weight[x] | 5 ) < (*_http_filter_weight[y] | 5)},
					)

		// Set a default external_secret for DEV mode redis connections.
		// NOTE: we have to do another IF statement for the OIDC check
		// due to CUE scoping. If we use the check inside of the `http_filters` object
		// CUE loses scope and evaluation fails.
		_external_filter_secrets: metrics_receiver_secret: defaults.metrics_receiver
		if _enable_oidc_authentication {
			_external_filter_secrets: oidc_authn_secret: defaults.edge.oidc.client_secret
		}

		// http_filters contains the configuration for HTTP filters (not TCP)
		// potentially applied to the listener. Note again that the active_http_filters
		// list controls which filters are actually used with incoming requests.
		http_filters: {
			// gm_metrics collects real-time statistics for the running service
			// and serves them to a metrics scraper like Prometheus. These defaults should
			// work for most use cases. 
			gm_metrics: {
				metrics_host:                               "0.0.0.0"
				metrics_port:                               defaults.ports.metrics
				metrics_dashboard_uri_path:                 "/metrics"
				metrics_prometheus_uri_path:                "/prometheus"
				metrics_ring_buffer_size:                   4096
				prometheus_system_metrics_interval_seconds: 15
				metrics_key_function:                       "depth"
				metrics_key_depth:                          string | *"1"
				metrics_receiver: {
					// The connection string gets set by the external secret mechnanism in secrets/
					redis_connection_string?: string
					push_interval_seconds:    10
				}
			}

			// gm_observables configures the proxy to emit information about each request made to 
			// the service for audits.
			gm_observables: {
				topic: _gm_observables_topic
			}

			if _enable_oidc_authentication {
				_authRealms:      string | *"realms"
				_authAdminRealms: string | *"admin/realms"
				if _keycloak_pre_17 {
					_authRealms:      "auth/realms"
					_authAdminRealms: "auth/admin/realms"
				}
				_oidc_provider:           "\(defaults.edge.oidc.endpoint)/\(_authRealms)/\(defaults.edge.oidc.realm)"
				"gm_oidc-authentication": #oidc_authentication & {
					authRealms:      _authRealms
					authAdminRealms: _authAdminRealms
					// These values are populated from inputs.cue
					serviceUrl: _oidc_service_url
					provider:   _oidc_provider
					clientId:   _oidc_client_id
					accessToken: {
						cookieOptions: {
							domain: _oidc_cookie_domain
						}
					}
					idToken: {
						cookieOptions: {
							domain: _oidc_cookie_domain
						}
					}
					tokenRefresh: {
						endpoint: _oidc_endpoint
						realm:    _oidc_realm
					}
				}
				"gm_ensure-variables": #ensure_variables_filter
				"gm_oidc-validation":  httpFilters.#ValidationConfig & {
					provider: _oidc_provider
					enforce:  bool | *false
					if enforce {
						enforceResponseCode: int32 | *403
					}
					accessToken: {
						key:      "access_token"
						location: *"cookie" | _
						if location == "metadata" {
							metadataFilter: string
						}
					}
					userInfo: {
						location: *"header" | _
						// USER_DN header is currently required for observables
						// application to show user audit data.
						key: "USER_DN"
						claims: ["name"]
					}
					TLSConfig?: {
						useTLS:             bool | *true
						insecureSkipVerify: bool | *false
					}
				}
				// Use Lua pattern matching to get the user's name from encoded JSON object.
				"envoy_lua": lua.#Lua & {
					inline_code: """
							function envoy_on_request(handle)
								local user_dn = handle:headers():get('USER_DN')
								parsed_user_dn = string.match(user_dn, '%%7B%%22name%%22:%%22(.*)%%22%%7D')
								parsed_user_dn = string.gsub(parsed_user_dn, '%%20', ' ')
								handle:headers():replace('USER_DN', parsed_user_dn)
							end
						"""
				}
				"envoy_jwt_authn": #envoy_jwt_authn & {
					providers: defaults.edge.oidc.jwt_authn_provider
					providers: keycloak: issuer: _oidc_provider

					if defaults.edge.oidc.enable_remote_jwks {
						providers: keycloak: remote_jwks: http_uri: {
							cluster: defaults.edge.oidc.remote_jwks_cluster
							uri:     *"\(_oidc_provider)/protocol/openid-connect/certs" | string
						}
					}
				}
			}
			if _enable_rbac {
				envoy_rbac: #envoy_rbac_filter
			}
			if _enable_fault_injection {
				envoy_fault: #envoy_fault_injection
			}
			if _enable_inheaders {
				gm_inheaders: debug: bool | *false
			}
			if _enable_impersonation {
				gm_impersonation: {
					servers:       string | *""
					caseSensitive: bool | *false
				}
			}
			if _enable_jwt_security {
				"gm_jwtsecurity": #jwt_security_filter
			}
			if _enable_ext_authz {
				envoy_ext_authz: #envoy_ext_authz
			}
		}
	}

	if _security_spec.internal.type == "spire" && _spire_self != _|_ {
		secret: #spire_secret & {
			// Expects _name and _subject to be passed in like so from above:
			// _spire_self: "dashboard"
			// _spire_other: "edge"  // but this defaults to "edge" and may be omitted
			_name:    _spire_self
			_subject: _spire_other
			set_current_client_cert_details: URI: true
			forward_client_cert_details: "APPEND_FORWARD"
		}
	}

	// calculate all external secrets
	external_secrets: [ for k, v in _external_filter_secrets {v}]

	zone_key: mesh.spec.zone
}

// #cluster represents "upstream" or outgoing traffic from the proxy. Generally, this is
// the service fronted by the proxy but could be any network address. #cluster can support
// TLS configuration to the upstream service.
#cluster: greymatter.#Cluster & {
	// You can either specify the upstream with these, or leave it to service discovery
	_upstream_host:           string | *"127.0.0.1"
	_upstream_port:           int
	_force_https:             *false | true
	_spire_self:              string // can specify current identity - defaults to "edge"
	_spire_other:             string // can specify an allowable upstream identity - defaults to "edge"
	_enable_circuit_breakers: bool | *false
	// We can expand options here for load balancers that superseed the lb_policy field
	_load_balancer:    *"round_robin" | "least_request" | "maglev" | "ring_hash" | "random"
	_trust_file:       string
	_certificate_path: string | *"/etc/proxy/tls/sidecar/server.crt"
	_key_path:         string | *"/etc/proxy/tls/sidecar/server.key"
	// Set _require_client_certs for TLS enabled sidecars to require
	// x.509 client certificates during the TLS handshake. For web browsers,
	// the user will need to load their certificate into their browser or
	// computer's certificate storage.
	_require_client_certs: bool | *false

	cluster_key: string
	name:        string | *cluster_key
	instances:   [...greymatter.#Instance] | *[]

	if _upstream_port != _|_ {
		instances: [{host: _upstream_host, port: _upstream_port}]
	}
	if _security_spec.internal.type == "spire" && _spire_other != _|_ {
		require_tls: true
		secret:      #spire_secret & {
			// Expects _name and _subject to be passed in like so from above:
			// _spire_self: "redis"  // but this defaults to "edge" and may be omitted
			// _spire_other: "dashboard"
			_name:    _spire_self
			_subject: _spire_other
		}
	}

	_require_client_certs: [
				if _security_spec.internal.type == "manual-tls" {false},
				if _security_spec.internal.type == "manual-mtls" {true},
				false,
	][0]
	_enable_ssl_block: [
				if (_security_spec.internal.type == "manual-mtls") {true},
				if (_security_spec.internal.type == "manual-tls") {true},
				if ( _security_spec.internal.type == "plaintext" ) {false},
				if ( _security_spec.internal.type == "spire") {false},
				false,
	][0]

	// if len(instances) == 0 then it is using service discovery (so a cluster from a sidecar going to another sidecar)
	if (name != defaults.edge.key && _enable_ssl_block && len(instances) == 0) || _force_https {
		require_tls: true
		ssl_config: {
			cert_key_pairs: [{
				certificate_path: _certificate_path
				key_path:         _key_path
			}]
		}
		if _require_client_certs {
			ssl_config: trust_file: _trust_file | *"/etc/proxy/tls/sidecar/ca.crt"
		}
	}

	zone_key: mesh.spec.zone

	if _enable_circuit_breakers {
		// circuit_breakers can specify circuit breaker levels for normal and high
		// priority traffic with configured defaults
		circuit_breakers: greymatter.#CircuitBreakersThresholds & {
			#circuit_breakers_default
			high?: #circuit_breakers_default
		}
	}

	// Allows for configuration of a load balancer, designated by the policy type.
	if _load_balancer != _|_ {
		lb_policy: _load_balancer
		if lb_policy == "least_request" {
			least_request_lb_config: {
				choice_count: uint32 | *2
			}
		}

		if lb_policy == "ring_hash" || lb_policy == "maglev" {
			ring_hash_lb_config: {
				minimum_ring_size?: uint64 & <8388608 | *1024
				hash_func?:         uint32 | *0                  //corresponds to the xxHash; 1 for MURMUR_HASH_2 
				maximum_ring_size?: uint64 & <8388608 | *4194304 // 4M
			}
		}
	}
}

// #circuit_breakers_default provides default circuit breaker values.
// Setting _enable_circuit_breakers: true on the #cluster will use these values
// unless overriden.
#circuit_breakers_default: {
	max_connections:      int64 | *1024
	max_pending_requests: int64 | *1024
	max_requests:         int64 | *1024
	max_retries:          int64 | *3
	max_connection_pools: int64 | *1024
	track_remaining:      bool | *false
}

// #route represents the URL path to a service in the mesh.
#route: greymatter.#Route & {
	route_key:               string
	domain_key:              string | *route_key
	_upstream_cluster_key:   string | *route_key
	_enable_route_ext_authz: bool | *false
	route_match: {
		path:       string | *"/"
		match_type: string | *"prefix"
	}
	rules: [{
		constraints: light: [{
			cluster_key: _upstream_cluster_key
			weight:      int | *1
		}, ...]
	}]
	zone_key:       mesh.spec.zone
	prefix_rewrite: string | *"/"
	filter_configs: {
		if _enable_route_ext_authz {
			envoy_ext_authz: ext_authz.#ExtAuthzPerRoute | *{disabled: true} // example: disable auth for landing page
		}
	}
}

// #proxy represents the sum total of all configurations sent to data plane proxy. This includes listeners,
// domains, routes, and clusters.
#proxy: greymatter.#Proxy & {
	proxy_key:     string
	name:          proxy_key
	domain_keys:   [...string] | *[proxy_key]
	listener_keys: [...string] | *[proxy_key]
	zone_key:      mesh.spec.zone
	filters: {}
}

#spire_secret: {
	_name:    string | *defaults.edge.key
	_subject: string | *defaults.edge.key
	_subjects?: [...string]

	set_current_client_cert_details?: {...}
	forward_client_cert_details?: string

	secret_validation_name: "spiffe://\(defaults.spire.trust_domain)"
	secret_name:            "spiffe://\(defaults.spire.trust_domain)/\(config.operator_namespace).\(mesh.metadata.name).\(_name)"
	if _subjects == _|_ {
		subject_names: ["spiffe://\(defaults.spire.trust_domain)/\(config.operator_namespace).\(mesh.metadata.name).\(_subject)"]
	}
	if _subjects != _|_ {
		subject_names: [ for s in _subjects {"spiffe://\(defaults.spire.trust_domain)/\(config.operator_namespace).\(mesh.metadata.name).\(s)"}]
	}
	ecdh_curves: ["X25519:P-256:P-521:P-384"]
}

// #envoy_rbac_filter allows for RBAC permissions to be applied to a service and its configuration.
#envoy_rbac_filter: rbac.#RBAC | *#default_rbac

// #default_rbac allows all traffic to flow with no restriction.
#default_rbac: {
	rules: {
		action: "ALLOW"
		policies: {
			all: {
				permissions: [
					{
						any: true
					},
				]
				principals: [
					{
						any: true
					},
				]
			}
		}
	}
}

// #ensure_variables_filter is used by OIDC/JWT authentication and ensures that
// the access_token JWT that is present as a cookie is copied into the header
// of the request so that it can be accessed by the envoy_jwt_authn filter.
#ensure_variables_filter: httpFilters.#EnsureVariablesConfig & _ensure_variables_filter_default
_ensure_variables_filter_default: {
	rules: *[
		{
			copyTo: [
				{
					key:      "access_token"
					location: "header"
				},
			]
			key:      "access_token"
			location: "cookie"
		},
	] | _
}

// #envoy_jwt_authn allows for the JWT supplied by an OIDC provider to be validated and 
// used in other contexts, such as RBAC configurations.
#envoy_jwt_authn: jwt_authn.#JwtAuthentication & {
	providers: {
		// keycloak configuration is specific to Keycloak. If using another provider, you will need to
		// create separate set of configurations and change the provider_name in the rules below.
		keycloak?: {
			remote_jwks?: {
				http_uri: {
					timeout: string | *"1s"
				}
				cache_duration: string | *"300s"
			}
			forward:             bool | *true
			from_headers:        [...] | *[{name: "access_token"}]
			payload_in_metadata: string | *"claims"
		}
	}
	rules: [...] | *[
		{
			match: {prefix: "/"}
			requires: {provider_name: "keycloak"} //This name is configurable 
		},
	]
}

// #oidc_authentication allows for authentication via an OIDC provider such as Keycloak.

_oidc_authentication_defaults: {
	callbackPath: *"/oauth" | _
	useTLS:       *true | _
	accessToken: {
		location: "header" | "queryString" | "metadata" | *"cookie"
		key:      *"access_token" | _
		if location == "metadata" {
			metadataFilter: string
		}
		if location == "cookie" {
			cookieOptions: {
				httpOnly: *true | _
				secure:   bool | *defaults.edge.enable_tls
				maxAge:   *"6h" | _
				domain:   *"" | _
				path:     *"/" | _
			}
		}
	}

	idToken: {
		location: *"cookie" | _
		key:      *"authz_token" | _
		if location == "cookie" {
			cookieOptions: {
				httpOnly: *true | _
				secure:   bool | *defaults.edge.enable_tls
				maxAge:   *"6h" | _
				domain:   *"" | _
				path:     *"/" | _
			}
		}
	}

	tokenRefresh: {
		enabled:   *true | _
		timeoutMs: *5000 | _
		useTLS:    *true | _
	}

	// Optional requested permissions
	additionalScopes: [...string] | *["openid"] //This scope is required for OIDC
}
#oidc_authentication: httpFilters.#AuthenticationConfig & _oidc_authentication_defaults

#envoy_tcp_rate_limit: ratelimit.#RateLimit | *#default_rate_limit

// #default_rate_limit assumes the http/2 cluster between proxy and the rate limit service is called ratelimit.
// See https://www.envoyproxy.io/docs/envoy/latest/intro/arch_overview/other_features/global_rate_limiting#arch-overview-global-rate-limit
// for a discussion of ratelimiting and special descriptors to use.
#default_rate_limit: ratelimit.#RateLimit & {
	stat_prefix:       defaults.edge.key
	domain:            defaults.edge.key
	failure_mode_deny: true
	descriptors: [
		{
			entries: [
				{
					key:   "path"
					value: "/"
				},
			]
		},
	]
	rate_limit_service: {
		transport_api_version: "V3"
		grpc_service: {
			envoy_grpc: {
				cluster_name: "ratelimit"
			}
		}
	}
}

// #envoy_fault_injection allows for the configuration of fault injection into a proxy
// See https://www.envoyproxy.io/docs/envoy/v1.16.5/configuration/http/http_filters/fault_filter.html
// for header/runtime configuration specifics, along with further configuration for specific upstream clusters.
#envoy_fault_injection: fault.#HTTPFault | *{
	delay: {
		fixed_delay: "5s"
		percentage: {
			numerator:   50
			denominator: "HUNDRED"
		}
	}
	abort: {
		// header_abort allows request to specify the status code with which to fail using the x-envoy-fault-abort-request header
		header_abort: {} // Headers can also specify the percentage of requests to fail, capped by the below value with the x-envoy-fault-abort-request-percentage header
		percentage: {
			numerator:   50
			denominator: "HUNDRED"
		}
	}
}

// See https://www.envoyproxy.io/docs/envoy/v1.16.5/configuration/http/http_filters/ext_authz_filter for additional configuration including
// interfacing with a traditional HTTP/1 authorization service.
#envoy_ext_authz: ext_authz.#ExtAuthz | *{
	transport_api_version: "V3"
	grpc_service: {
		envoy_grpc: {
			cluster_name: "opa" // Needs to match the name of your cluster. Since its a grpc connection, you must create an http/2 cluster
		}
	}
	failure_mode_allow: false // set to true to allow requests to pass in the case of a authz network failure
	with_request_body: {
		max_request_bytes:     1024
		allow_partial_message: true
		pack_as_bytes:         true
	}
}

#envoy_tcp_ext_authz: ext_authz_tcp.#ExtAuthz | *{
	transport_api_version: "V3"
	grpc_service: {
		envoy_grpc: {
			cluster_name: "ext_authz_tcp" // Needs to match the name of your cluster
		}
	}
	failure_mode_allow: false // set to true to allow requests to pass in the case of a authz network failure
}

// #opa_egress configures egress to an OPA service for external authorization.
#opa_egress: {
	input: {
		service_name: string
		domain_key:   string
	}
	_opa_key: "\(input.service_name)-egress-to-opa"
	out: {
		config: [
			#cluster & {
				cluster_key: _opa_key
				name:        "opa"
				http2_protocol_options: {
					allow_connect: true
				}
			},
			#route & {route_key: _opa_key, domain_key: input.domain_key},
		]
	}
}

_jwt_egress_port: 10900
#jwt_security_filter: {
	apiKey:             string
	endpoint:           string | *"http://localhost:\(_jwt_egress_port)"
	jwtHeaderName:      string | *"x-jwt-token"
	useTls:             bool | *false
	certPath:           string | *"./certs/server.crt"
	keyPath:            string | *"./certs/server.key"
	caPath:             string | *"./certs/intermediate.crt"
	insecureSkipVerify: bool | *false
	timeoutMs:          int | *1000 //milliseconds
	maxRetries:         int | *0
	retryDelayMs:       int | *0   //milliseconds
	cacheLimit:         int | *100 //number of tokens stored
	cachedTokenExp:     int | *10  //minutes
}

#jwt_security_egress: {
	input: {
		service_name: string
	}
	out: {
		key: "\(input.service_name)-egress-to-jwt"
		config: [
			#domain & {
				domain_key: key
				port:       _jwt_egress_port
			},
			#listener & {
				listener_key: key
				ip:           "127.0.0.1"
				port:         _jwt_egress_port
			},

			#cluster & {
				cluster_key: key
				name:        "jwt-security"
			},
			#route & {
				route_key: key
			},
			...,
		]
	}
}

#catalog_entry: greymatter.#CatalogService
