package greymatter

import (
	corev1 "k8s.io/api/core/v1"
	greymatter "greymatter.io/api"
	"github.com/greymatter-io/operator/api/meshv1"
)

config: {
	// Flags
	// use Spire-based mTLS (ours or another)
	spire: bool | *false @tag(spire,type=bool)
	// deploy our own server and agent
	deploy_spire: bool | *spire @tag(use_spire,type=bool)
	// if we're deploying into OpenShift, request extra permissions
	openshift: bool | *false @tag(openshift,type=bool)
	// deploy and configure Prometheus for historical metrics in the Dashboard
	enable_historical_metrics: bool | *true @tag(enable_historical_metrics,type=bool)
	// deploy and configure audit pipeline for observability telemetry
	enable_audits: bool | *true @tag(enable_audits,type=bool)
	// whether to automatically copy the image pull secret to watched namespaces for sidecar injection
	auto_copy_image_pull_secret: bool | *true @tag(auto_copy_image_pull_secret, type=bool)
	// namespace the operator will deploy into
	operator_namespace: string | *"gm-operator" @tag(operator_namespace, type=string)

	cluster_ingress_name: string | *"cluster" // For OpenShift deployments, this is used to look up the configured ingress domain

	// currently just controls k8s/outputs/operator.cue for debugging
	debug: bool | *false @tag(debug,type=bool)
	// test=true turns off GitOps, telling the operator to use the baked-in CUE
	test: bool | *false @tag(test,type=bool) // currently just turns off GitOps so CI integration tests can manipulate directly
}

mesh: meshv1.#Mesh & {
	metadata: {
		name: string | *"greymatter-mesh"
	}
	spec: {
		install_namespace: string | *"greymatter"
		watch_namespaces:  [...string] | *["default", "examples"]
		images: {
			proxy:       string | *"greymatter.jfrog.io/oci/greymatter-proxy:1.9.1-beta1"
			catalog:     string | *"greymatter.jfrog.io/oci/greymatter-catalog:3.2.0-beta1"
			dashboard:   string | *"greymatter.jfrog.io/oci/greymatter-dashboard:6.2.0-beta1"
			control:     string | *"greymatter.jfrog.io/oci/greymatter-control:1.9.1-beta1"
			control_api: string | *"greymatter.jfrog.io/oci/greymatter-control-api:1.9.1-beta1"
			redis:       string | *"greymatter.jfrog.io/oci/redis-stack-server:6.2.6-v7-20230504"
			prometheus:  string | *"index.docker.io/prom/prometheus:v2.40.1"
		}
		// NOTE: This value MUST be set before installation. It cannot be changed after the fact and 
		// would require a mesh re-installation if a change is necessary.
		display_name: string | *"Greymatter Mesh"
	}
}

defaults: {
	image_pull_secret_name: string | *"greymatter-image-pull"
	image_pull_policy:      corev1.#enumPullPolicy | *corev1.#PullAlways
	xds_host:               "controlensemble.\(mesh.spec.install_namespace).svc.cluster.local"
	sidecar_list:           [...string] | *["dashboard", "catalog", "controlensemble", "edge", "redis", "prometheus", "jwtsecurity", "audits"]
	allow_multi_sidecar:    bool | *false // Allows multiple sidecars to run in a single host pod. By default, only one sidecar is allowed per pod. 
	proxy_port_name:        "ingress" // the name of the ingress port for sidecars - used by service discovery
	metrics_port_name:      "stats"   // the name of the metrics port for sidecars - used by Prometheus scrape
	redis_cluster_name:     "greymatter-datastore"
	redis_host:             "\(redis_cluster_name).\(mesh.spec.install_namespace).svc.cluster.local"
	redis_port:             6379
	redis_db:               0
	redis_username:         ""
	redis_password:         ""
	metrics_receiver:       #MetricsRedisSecret & {
		greymatter.#PlaintextSecret

		plaintext_secret: {
			secret: "redis://127.0.0.1:\(defaults.ports.redis_ingress)"
		}
	}

	// key names for applied-state backups to Redis - they only need to be unique.
	gitops_state_key_gm:      "\(config.operator_namespace).gmHashes"
	gitops_state_key_k8s:     "\(config.operator_namespace).k8sHashes"
	gitops_state_key_sidecar: "\(config.operator_namespace).sidecarHashes"

	// mesh_connections_secret pertains to the mesh connections feature in greymatter.
	// Edge and catalog read certificates off-disk from a secret.
	// This is for inbound/outbound traffic to this mesh from other
	// greymatter meshes.
	mesh_connections_secret: "greymatter-mesh-connections-certs"

	ports: {
		default_ingress: 10908
		edge_ingress:    defaults.ports.default_ingress
		redis_ingress:   10910
		metrics:         8082
		envoy_admin:     8002
	}

	images: {
		cli:               string | *"greymatter.jfrog.io/oci/greymatter-cli:4.8.1-beta1"
		operator:          string | *"greymatter.jfrog.io/oci/greymatter-operator:0.18.0-beta1" @tag(operator_image)
		vector:            string | *"timberio/vector:0.22.0-debian"
		audits:            string | *"greymatter.jfrog.io/oci/greymatter-audits:1.1.7"
	}

	prometheus: {
		// external_host instructs greymatter to install Prometheus or use an
		// externally hosted one. If enable_historical_metrics is true and external_host
		// is empty, then greymatter will install Prometheus into the greymatter
		// namespace. If enable_historical_metrics is true and external_host has a
		// value, greymatter will not install Prometheus into the greymatter namespace
		// and will connect to the external Prometheus via a sidecar
		// (e.g. external_host: prometheus.metrics.svc).
		external_host: ""
		port:          9090
		tls: {
			enabled:     false
			cert_secret: "gm-prometheus-certs"
		}
	}

	// audits configuration applies to greymatter's observability pipeline and are
	// used when config.enable_audits is true.  
	audits: {
		// storage_index is the index name to write audit events to. The default
		// naming convention will generate a new index for each month of each year.
		// The naming configuration can be changed to create more or less indexes
		// depending on your storage and performance requirements.
		storage_index: "gm-audits-%Y-%m"
		// query_index is the index pattern used by the audit application to
		// query audit documents in Elasticsearch. If you change storage_index,
		// you may need to change this pattern too. 
		query_index: "gm-audits*"
		// elasticsearch_host can be an IP address or DNS hostname to your Elasticsearch instance.
		// It's set to a non-empty value so that the audit-pipeline starts successfully.
		elasticsearch_host: "127.0.0.1"
		// elasticsearch_port is the port of your Elasticsearch instance.
		elasticsearch_port: 443
		// elasticsearch_endpoint is the full endpoint containing protocol, host, and port
		// of your Elasticsearch instance. This is used by to sync audit data
		// with Elasticsearch.
		elasticsearch_endpoint: "https://\(elasticsearch_host):\(elasticsearch_port)"
		// elasticsearch_secret is the name of the secret containing the elasticsearch username 
		// and password
		elasticsearch_secret: "greymatter-audits"
		// elasticsearch_tls_verify_certificate determines if the audit agent verifies
		// Elasticsearch's TLS certificate during the TLS handshake. If your Elasticsearch is
		// using a self-signed certificate, set this to false.
		elasticsearch_tls_verify_certificate: true
	}

	edge: {
		// key is the unique key of the edge proxy. Certain features of the mesh
		// rely on this value, such as the audit app's queries to Elasticsearch. 
		// The value should not need to be changed.
		key: "edge"
		// enable_tls enables TLS on the edge proxy. This config also enables
		// internal TLS across sidecars. That behavior can be changed by
		// setting defaults.internal.core_internal_tls_certs.enable to false.
		enable_tls: bool | *false @tag(edge_enable_tls,type=bool)
		// require_client_certs enables mTLS on the edge proxy. This requires
		// that edge.enable_tls is also true. This config also enables internal
		// mTLS across sidecars. That behavior can be changed by setting the
		// defaults.internal.core_internal_tls_certs.require_client_certs to true.
		require_client_certs: bool | *false @tag(edge_require_client_certs, type=bool)
		secret_name:          "greymatter-edge-ingress"
		annotations: {
			// Additional annotations for the core edge service. ex: ["annotation_key_1:value1", "annotation_key_2:value2"]
			service: [...string] | *[]
		}
		oidc: {
			// upstream_host is the FQDN of your OIDC service.
			upstream_host: "foobar.oidc.com"
			// upstream_port is the port your OIDC service is listening on.
			upstream_port: 443
			// endpoint is the protocol, host, and port of your OIDC service.
			// If the upstream_port is 443, it's unnecessary to provide it. If
			// the upstream_port is not 443, you must provide it with: "https://\(upstream_host):\(upstream_port)".
			endpoint: "https://\(upstream_host)"
			// edge_domain is the FQDN of your edge service. It's used by
			// greymatter's OIDC filters, and will be used to redirect the user
			// back to the mesh, upon successful authentication.
			edge_domain: "foobar.com"
			// realm is the ID of a realm in your OIDC provider.
			realm: "greymatter"
			// client_id is the ID of a client in a realm in your OIDC provider.
			client_id: "greymatter"
			// client_secret is the secret key of a client in a realm in your
			// OIDC provider. It must be provided as a kubernetes secret in the 
			// target namespace. Uncomment this block when using OIDC.
			// client_secret: #OIDCSecret & {
			// 	greymatter.#KubernetesSecret

			// 	kubernetes_secret: {
			// 		namespace: mesh.spec.install_namespace
			// 		name:      "greymatter-oidc-provider"
			// 		key:       "client-secret"
			// 	}
			// }
			// enable_remote_jwks is a toggle that automatically enables remote
			// JSON Web Key Sets (JWKS) verification with your OIDC provider.
			// Alternatively, you can disable this and use local_jwks below.
			// It's advised to enable remote JWKS because it is reslient to 
			// key rotation.
			enable_remote_jwks: false
			// remote_jwks_cluster is the name of the egress cluster used by
			// the edge proxy to make connections to your OIDC service.
			remote_jwks_cluster: "edge_egress_to_oidc"
			// remote_jwks_egress_port is the port used by the edge proxy to make egress
			// connections to your upstream OIDC service's JWKS endpoint. This is fairly
			// static and you should not have to change the value.
			remote_jwks_egress_port: 8443
			// jwt_authn_provider contains configuration for JWT authentication.
			// This is used in conjunction with remote JWKS or local JWKS.
			jwt_authn_provider: {
				keycloak: {
					audiences: ["greymatter"]
					// If using local JWKS verification, disable enable_remote_jwks above and
					// uncomment local_jwks below. You will need to paste the JWKS JSON
					// from your OIDC provider inside the inline_string's starting and ending
					// triple quotes.
					// local_jwks: {
					//  inline_string: #"""
					//   {}
					//   """#
					// }
				}
			}
		}
	} // edge

	spire: {
		// namespace is where SPIRE server and agents are deployed to.
		namespace: "spire"
		// trust_domain is the trust domain that must match what's configured at the server.
		trust_domain: "greymatter.io"
		// socket_mount_path is the mount path of the SPIRE socket for communication with an agent.
		socket_mount_path: "/run/spire/socket"
		// ca_secret_name is the name of the secret that is injected when config.deploy_spire is true.
		ca_secret_name: "server-ca"
	}

	core_internal_tls_certs: {
		// enable enables internal sideacr TLS (requires defaults.edge.enable_tls=true)
		enable: bool | *defaults.edge.enable_tls @tag(internal_enable_tls,type=bool)
		// require_client_certs enables internal mTLS (requires: defaults.edge.enable_tls=true and defaults.core_internal_tls_certs.enable=true)
		require_client_certs: bool | *defaults.edge.require_client_certs @tag(internal_require_client_certs, type=bool)
		// cert_secret is the name of the Kubernetes secret to be mounted.
		// By default the same secret for external TLS/mTLS will be used for internal TLS/mTLS.
		// Different certs can be used by specifying a different secret name.
		cert_secret: string | *defaults.edge.secret_name
	}

	additional_labels: {
		// Labels to add to all greymatter core pods
		all_pods: [...string] | *[]
		// If integrating with an external spire that uses pod_labels for registration
		// Add the label it is looking for and this label will be added to all greymatter
		// core components
		external_spire_label: string | *""
		// Labels to add to the edge service
		edge_service: [...string] | *[]
	}

} // defaults
