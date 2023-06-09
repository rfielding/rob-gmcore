package api

import (
	"greymatter.io/api/filters/http"
	"greymatter.io/api/filters/network"
)

// Copied Envoy definitions 
// must be present due to us not conforming with CUE package import rules
#DownstreamTlsContext_OcspStaplePolicy: "LENIENT_STAPLING" | "STRICT_STAPLING" | "MUST_STAPLE"

// Google's `RE2 <https://github.com/google/re2>`_ regex engine. The regex string must adhere to
// the documented `syntax <https://github.com/google/re2/wiki/Syntax>`_. The engine is designed
// to complete execution in linear time as well as limit the amount of memory used.
//
// Envoy supports program size checking via runtime. The runtime keys `re2.max_program_size.error_level`
// and `re2.max_program_size.warn_level` can be set to integers as the maximum program size or
// complexity that a compiled regex can have before an exception is thrown or a warning is
// logged, respectively. `re2.max_program_size.error_level` defaults to 100, and
// `re2.max_program_size.warn_level` has no default if unset (will not check/log a warning).
//
// Envoy emits two stats for tracking the program size of regexes: the histogram `re2.program_size`,
// which records the program size, and the counter `re2.exceeded_warn_level`, which is incremented
// each time the program size exceeds the warn level threshold.
#RegexMatcher_GoogleRE2: {
	// This field controls the RE2 "program size" which is a rough estimate of how complex a
	// compiled regex is to evaluate. A regex that has a program size greater than the configured
	// value will fail to compile. In this case, the configured max program size can be increased
	// or the regex can be simplified. If not specified, the default is 100.
	//
	// This field is deprecated; regexp validation should be performed on the management server
	// instead of being done by each individual client.
	//
	// Deprecated: Do not use.
	max_program_size?: uint32
}

// A regex matcher designed for safety when used with untrusted input.
#RegexMatcher: {
	// Google's RE2 regex engine.
	google_re2?: #RegexMatcher_GoogleRE2
	// The regex match string. The string must be supported by the configured engine.
	regex?: string
}

#StringMatcher: {
	// The input string must match exactly the string specified here.
	//
	// Examples:
	//
	// * *abc* only matches the value *abc*.
	exact?: string
	// The input string must have the prefix specified here.
	// Note: empty prefix is not allowed, please use regex instead.
	//
	// Examples:
	//
	// * *abc* matches the value *abc.xyz*
	prefix?: string
	// The input string must have the suffix specified here.
	// Note: empty prefix is not allowed, please use regex instead.
	//
	// Examples:
	//
	// * *abc* matches the value *xyz.abc*
	suffix?: string
	// The input string must match the regular expression specified here.
	safe_regex?: #RegexMatcher
	// The input string must have the substring specified here.
	// Note: empty contains match is not allowed, please use regex instead.
	//
	// Examples:
	//
	// * *abc* matches the value *xyz.abc.def*
	contains?: string
	// If true, indicates the exact/prefix/suffix/contains matching should be case insensitive. This
	// has no effect for the safe_regex match.
	// For example, the matcher *data* will match both input string *Data* and *data* if set to true.
	ignore_case?: bool
}

#SubjectAltNameMatcher_SanType: "SAN_TYPE_UNSPECIFIED" | "EMAIL" | "DNS" | "URI" | "IP_ADDRESS"
#SubjectAltNameMatcher: {
	// Specification of type of SAN. Note that the default enum value is an invalid choice.
	san_type?: #SubjectAltNameMatcher_SanType
	// Matcher for SAN value.
	matcher?: #StringMatcher
}

#Cluster: {
	name:         string
	cluster_key:  string
	zone_key:     string
	require_tls?: bool
	lb_policy?:   string
	dns_type?:    string
	instances?: [...#Instance]
	health_checks?: [...#HealthCheck]
	outlier_detection?:       #OutlierDetection
	circuit_breakers?:        #CircuitBreakersThresholds
	ring_hash_lb_config?:     #RingHashLbConfig
	original_dst_lb_config?:  #OriginalDstLbConfig
	least_request_lb_config?: #LeastRequestLbConfig
	common_lb_config?:        #CommonLbConfig

	// common.cue
	secret?:                 #Secret
	ssl_config?:             #ClusterSSLConfig
	http_protocol_options?:  #HTTPProtocolOptions
	http2_protocol_options?: #HTTP2ProtocolOptions
	checksum?:               string
	org_key?:                string
	protocol_selection?:     string
}

#Instance: {
	host: string
	port: int32
}

#HealthCheck: {
	timeout_msec?:                 int64
	interval_msec?:                int64
	interval_jitter_msec?:         int64
	unhealthy_threshold?:          int64
	healthy_threshold?:            int64
	reuse_connection?:             bool
	no_traffic_interval_msec?:     int64
	unhealthy_interval_msec?:      int64
	unhealthy_edge_interval_msec?: int64
	healthy_edge_interval_msec?:   int64
	health_checker?:               #HealthChecker
}

#HealthChecker: {
	http_health_check?: #HTTPHealthCheck
	tcp_health_check?:  #TCPHealthCheck
}

#TCPHealthCheck: {
	send?: string
	receive?: [...string]
}

#HTTPHealthCheck: {
	host?:         string
	path?:         string
	service_name?: string
	request_headers_to_add?: [...#Metadata]
}

#OutlierDetection: {
	interval_msec?:                         int64
	base_ejection_time_msec?:               int64
	max_ejection_percent?:                  int64
	consecutive_5xx?:                       int64
	enforcing_consecutive_5xx?:             int64
	enforcing_success_rate?:                int64
	success_rate_minimum_hosts?:            int64
	success_rate_request_volume?:           int64
	success_rate_stdev_factor?:             int64
	consecutive_gateway_failure?:           int64
	enforcing_consecutive_gateway_failure?: int64
}

#CircuitBreakersThresholds: {
	max_connections?:      int64
	max_pending_requests?: int64
	max_requests?:         int64
	max_retries?:          int64
	max_connection_pools?: int64
	track_remaining?:      bool
	high?:                 #CircuitBreakersThresholds
}

#RingHashLbConfig: {
	minimum_ring_size?: uint64
	hash_func?:         uint32
	maximum_ring_size?: uint64
}

#OriginalDstLbConfig: use_http_header?: bool

#LeastRequestLbConfig: choice_count?: uint32

#CommonLbConfig: {
	healthy_panic_threshold?:              #Percent
	zone_aware_lb_config?:                 #ZoneAwareLbConfig
	consistent_hashing_lb_config?:         #ConsistentHashingLbConfig
	update_merge_window?:                  #Duration
	ignore_new_hosts_until_first_hc?:      bool
	close_connections_on_host_set_change?: bool
}

#Percent: value?: float64

#ZoneAwareLbConfig: {
	routing_enabled?:       #Percent
	min_cluster_size?:      uint64
	fail_traffic_on_panic?: bool
}

#ConsistentHashingLbConfig: use_hostname_for_hashing?: bool

#Duration: {
	seconds?: int64
	nanos?:   int32
}

// Route

#Route: {
	route_key:       string
	domain_key:      string
	zone_key:        string
	prefix_rewrite?: string
	cohort_seed?:    #CohortSeed
	high_priority?:  bool
	timeout?:        string
	idle_timeout?:   string
	rules: [...#Rule]
	route_match:    #RouteMatch
	response_data?: #ResponseData
	retry_policy?:  #RetryPolicy
	filter_metadata?: [string]: #Metadata
	filter_configs?: [string]: {...}
	request_headers_to_add?: [...#Metadatum]
	response_headers_to_add?: [...#Metadatum]
	request_headers_to_remove?: [...string]
	response_headers_to_remove?: [...string]
	redirects: [...#Redirect]
	shared_rules_key?: string
}

#RouteMatch: {
	path:       string
	match_type: string
}

#Rule: {
	rule_key?: string
	methods?: [...string]
	matches?: [...#Match]
	constraints?: #AllConstraints
	cohort_seed?: #CohortSeed
}

#Match: {
	kind?:     string
	behavior?: string
	from?:     #Metadatum
	to?:       #Metadatum
}

#Constraints: {
	light: [...#Constraint]
	dark?: [...#Constraint]
	tap?: [...#Constraint]
}

#Constraint: {
	cluster_key: string
	metadata?: [...#Metadata]
	properties?: [...#Metadata]
	response_data?: #ResponseData
	weight:         uint32
}

#ResponseData: {
	headers?: [...#HeaderDatum]
	cookies?: [...#CookieDatum]
}

#HeaderDatum: response_datum?: #ResponseDatum

#ResponseDatum: {
	name?:             string
	value?:            string
	value_is_literal?: bool
}

#CookieDatum: {
	expires_in_sec?:   uint32
	domain?:           string
	path?:             string
	secure?:           bool
	http_only?:        bool
	same_site?:        string
	name?:             string
	value?:            string
	value_is_literal?: bool
}

#RetryPolicy: {
	num_retries?:                       int64
	per_try_timeout_msec?:              int64
	timeout_msec?:                      int64
	retry_on?:                          string
	retry_priority?:                    string
	retry_host_predicate?:              string
	host_selection_retry_max_attempts?: int64
	retriable_status_codes?:            int64
	retry_back_off?:                    #BackOff
	retriable_headers?:                 #HeaderMatcher
	retriable_request_headers?:         #HeaderMatcher
}

#BackOff: {
	base_interval?: string
	max_interval?:  string
}

#HeaderMatcher: {
	name?:             string
	exact_match?:      string
	regex_match?:      string
	safe_regex_match?: #RegexMatcher
	range_match?:      #RangeMatch
	present_match?:    bool
	prefix_match?:     string
	suffix_match?:     string
	invert_match?:     bool
}

#RegexMatcher: {
	google_re2?: #GoogleRe2
	regex?:      string
}

#GoogleRe2: max_program_size?: int64

#RangeMatch: {
	start?: int64
	end?:   int64
}

// Domain

#Domain: {
	domain_key:   string
	zone_key:     string
	name:         string
	port:         int32
	force_https?: bool
	cors_config?: #CorsConfig
	aliases?: [...string]

	// common.cue
	ssl_config?: #ListenerSSLConfig
	redirects?: [...#Redirect]
	custom_headers?: [...#Metadatum]
	checksum?:     string
	gzip_enabled?: bool
	org_key?:      string
}

#ListenerSSLConfig: {
	allow_expired_certificate?: bool
	cert_key_pairs?: [...#CertKeyPathPair]
	cipher_filter?:                        string
	crl?:                                  #DataSource
	disable_stateless_session_resumption?: bool
	full_scan_sni?:                        bool
	match_subject_alt_names?: [...#SubjectAltNameMatcher]
	max_verify_depth?:   int
	ocsp_staple_policy?: #DownstreamTlsContext_OcspStaplePolicy
	only_leaf_cert_crl?: bool
	protocols?: [...string]
	require_client_certs?: bool
	session_ticket_key?: [...#DataSource]
	session_timeout?: string
	sni?: [...string]
	trust_chain_verification?: string
	trust_file?:               string
	verify_certificate_hash?: [...string]
	verify_certificate_spki?: [...string]
}

#ClusterSSLConfig: {
	allow_expired_certificate?: bool
	allow_renegotiation?:       bool
	cert_key_pairs?: [...#CertKeyPathPair]
	cipher_filter?: string
	crl?:           #DataSource
	match_subject_alt_names?: [...#SubjectAltNameMatcher]
	max_session_keys?:   int
	max_verify_depth?:   int
	only_leaf_cert_crl?: bool
	protocols?: [...string]
	sni?:                      string
	trust_chain_verification?: string
	trust_file?:               string
	verify_certificate_hash?: [...string]
	verify_certificate_spki?: [...string]
}

#CorsConfig: {
	allowed_origins?: [...#CORSAllowedOrigins]
	allow_credentials?: bool
	exposed_headers?: [...string]
	max_age?: int64
	allowed_methods?: [...string]
	allowed_headers?: [...string]
}

#CORSAllowedOrigins: {
	match_type?: string
	value?:      string
}

// Listener

#Listener: {
	name:         string
	listener_key: string
	zone_key:     string
	ip:           string
	port:         int32
	protocol:     string
	domain_keys: [...string]
	active_http_filters?: [...string]
	http_filters?: #HTTPFilters
	active_network_filters?: [...string]
	network_filters?:       #NetworkFilters
	stream_idle_timeout?:   string
	request_timeout?:       string
	drain_timeout?:         string
	delayed_close_timeout?: string
	use_remote_address?:    bool
	tracing_config?:        #TracingConfig
	access_loggers?:        #AccessLoggers
	external_secrets?: [...#FilterSecret]

	// common.cue
	secret?:                 #Secret
	http_protocol_options?:  #HTTPProtocolOptions
	http2_protocol_options?: #HTTP2ProtocolOptions
	checksum?:               string
	org_key?:                string
}

#HTTPFilters: {
	//Important: If your filter is multiple words, make it a quoted field
	//so that gm-control can pick up the configuration 
	gm_metrics?:               http.#MetricsConfig
	gm_impersonation?:         http.#ImpersonationConfig
	gm_inheaders?:             http.#InheadersConfig
	gm_listauth?:              http.#ListAuthConfig
	gm_observables?:           http.#ObservablesConfig
	"gm_ensure-variables"?:    http.#EnsureVariablesConfig
	gm_keycloak?:              http.#GmJwtKeycloakConfig
	gm_oauth?:                 http.#OauthConfig
	"gm_oidc-authentication"?: http.#AuthenticationConfig
	"gm_oidc-validation"?:     http.#ValidationConfig
	...
}

#NetworkFilters: {
	envoy_tcp_proxy?: {
		cluster:     string
		stat_prefix: string
	}
	gm_metrics?:     network.#tcpMetricsConfig
	gm_logger?:      network.#tcpLoggerConfig
	gm_observables?: network.#ObservablesTCPConfig
	gm_jwtsecurity?: network.#jwtSecurityTcpConfig
	...
}

#TracingConfig: {
	ingress?: bool
	request_headers_for_tags?: [...string]
}

#AccessLoggers: {
	http_connection_loggers?: #Loggers
	http_upstream_loggers?:   #Loggers
}

#Loggers: {
	disabled?: bool
	file_loggers?: [...#FileAccessLog]
	http_grpc_access_loggers?: [...#HTTPGRPCAccessLog]
}

#FileAccessLog: {
	path?:   string
	format?: string
	json_format?: [string]:       string
	typed_json_format?: [string]: string
}

#HTTPGRPCAccessLog: {
	common_config?: #GRPCCommonConfig
	additional_request_headers_to_log?: [...string]
	additional_response_headers_to_log?: [...string]
	additional_response_trailers_to_log?: [...string]
}

#GRPCCommonConfig: {
	log_name?:     string
	grpc_service?: #GRPCService
}

#GRPCService: {
	cluster_name?: string
}

// Proxy

#Proxy: {
	name:      string
	proxy_key: string
	zone_key:  string
	domain_keys: [...string]
	listener_keys: [...string]
	upgrades?: string
	active_filters?: [...string]
	checksum?: string
	filters:   #HTTPFilters
	listeners: [...#Listener]
	org_key?: string
}

// Catalog

#CatalogService: {
	mesh_id:                    string
	service_id:                 string
	name:                       string
	api_endpoint?:              string
	api_spec_endpoint?:         string
	description?:               string
	enable_instance_metrics?:   bool
	enable_historical_metrics?: bool
	business_impact?:           string
	version?:                   string
	owner?:                     string
	owner_url?:                 string
	capability?:                string
	runtime?:                   string
	documentation?:             string
	prometheus_job?:            string
	external_links?: [...#ExternalLink]
}

#SessionConfig: {
	url:        string
	use_tls?:   bool
	cert_path?: string
	key_path?:  string
	ca_path?:   string
	cluster?:   string
	region?:    string
	zone:       string
	sub_zone?:  string
}

#ExternalLink: {
	title: string
	url:   string
}

#MetricsReceiverSessionConfig: {
	client_type:       string
	connection_string: string
	cert_path?:        string
	key_path?:         string
	ca_path?:          string
}

#Metrics: {
	sessions:               #MetricsReceiverSessionConfig
	event_window_minutes?:  float
	event_timeout_minutes?: float
}

#Lad: {
	url:        string
	use_tls?:   bool
	cert_path?: string
	key_path?:  string
	ca_path?:   string
}

#Extension: {
	metrics?: #Metrics
	lad?:     #Lad
}

#MeshConfig: {
	mesh_id:     string
	mesh_type:   string
	name:        string
	sessions?:   #SessionConfig
	labels?:     string
	extensions?: #Extension
	externallinks?: [...#ExternalLink]
}

// Common

#Metadata: [...#Metadatum]

#Metadatum: {
	key:   string
	value: string
}

#Secret: {
	allow_expired_certificate?: bool
	cipher_filter?:             string
	crl?:                       #DataSource
	ecdh_curves?: [...string]
	forward_client_cert_details?: string
	match_subject_alt_names?: [...#SubjectAltNameMatcher]
	max_verify_depth?:                int
	only_leaf_cert_crl?:              bool
	secret_key?:                      string
	secret_name?:                     string
	secret_validation_name?:          string
	set_current_client_cert_details?: #ClientCertDetails
	subject_names?: [...string]
	trust_chain_verification?: string
	trust_file?:               string
	verify_certificate_hash?: [...string]
	verify_certificate_spki?: [...string]
}

#ClientCertDetails: URI: bool

#SSLConfig: {
	cipher_filter?: string
	protocols?: [...string]
	cert_key_pairs?: [...#CertKeyPathPair]
	require_client_certs?: bool
	trust_file?:           string
	sni?:                  [...string] | string
	crl?:                  #DataSource
}

#FilterSecret: {
	filter: string
	path:   string
	type:   string
	(#KubernetesSecret | #PlaintextSecret)
}

#KubernetesSecret: {
	#FilterSecret
	type: "kubernetes"

	kubernetes_secret: {
		namespace: string
		name:      string
		key:       key
	}
}

#PlaintextSecret: {
	#FilterSecret
	type: "plaintext"

	plaintext_secret: {
		secret: string
	}
}

#CertKeyPathPair: {
	certificate_path?: string
	key_path?:         string
	ocsp_staple_path?: string
}

#DataSource: {
	filename?:      string
	inline_string?: string
}

#HTTPProtocolOptions: {
	allow_absolute_url?:       bool
	accept_http_10?:           bool
	default_host_for_http_10?: string
	header_key_format?:        #HeaderKeyFormat
	enable_trailers?:          bool
}

#HeaderKeyFormat: proper_case_words?: bool

#HTTP2ProtocolOptions: {
	hpack_table_size?:                                     uint32
	max_concurrent_streams?:                               uint32
	initial_stream_window_size?:                           uint32
	initial_connection_window_size?:                       uint32
	allow_connect?:                                        bool
	max_outbound_frames?:                                  uint32
	max_outbound_control_frames?:                          uint32
	max_consecutive_inbound_frames_with_empty_payload?:    uint32
	max_inbound_priority_frames_per_stream?:               uint32
	max_inbound_window_update_frames_per_data_frame_sent?: uint32
	stream_error_on_invalid_http_messaging?:               bool
}

#Redirect: {
	name?:          string
	from?:          string
	to?:            string
	redirect_type?: string
	header_constraints?: [...#HeaderConstraint]
}

#HeaderConstraint: {
	name?:           string
	value?:          string
	case_sensitive?: bool
	invert?:         bool
}

// Shared Rules

#AllConstraints: {
	light?: [...#ClusterConstraint] | *null
	dark?:  [...#ClusterConstraint] | *null
	tap?:   [...#ClusterConstraint] | *null
}

#ClusterConstraint: {
	constraint_key?: string
	cluster_key?:    string
	metadata?:       #Metadata | *null
	properties?:     #Metadata | *null
	response_data?:  #ResponseData
	// We probably do not want to default the weight value
	weight?: uint32
}

#CohortSeed: {
	name?:                string
	type?:                string
	use_zero_value_seed?: bool
}

#SharedRules: {
	shared_rules_key: string
	name?:            string
	zone_key:         string
	default:          #AllConstraints
	rules:            [...#Rule] | *null
	response_data:    #ResponseData
	cohort_seed?:     #CohortSeed | *null
	properties?:      #Metadata | *null
	retry_policy?:    #RetryPolicy | *null
	org_key?:         string
	checksum?:        string
}

// Zone

#Zone: {
	zone_key: string
	name:     string
	org_key?: string
}
