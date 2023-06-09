// k8s manifests for controlensemble

package greymatter

import (
	appsv1 "k8s.io/api/apps/v1"
	corev1 "k8s.io/api/core/v1"
	rbacv1 "k8s.io/api/rbac/v1"
	"strings"
)

let Name = "controlensemble"
controlensemble: [
	appsv1.#StatefulSet & {
		apiVersion: "apps/v1"
		kind:       "StatefulSet"
		metadata: {
			name:      Name
			namespace: mesh.spec.install_namespace
		}
		spec: {
			serviceName: Name
			selector: {
				matchLabels: {"greymatter.io/cluster": Name}
			}
			template: {
				metadata: {
					labels: {
						"greymatter.io/cluster":  Name
						"greymatter.io/workload": "\(config.operator_namespace).\(mesh.metadata.name).\(Name)"
						for i in defaults.additional_labels.all_pods {
							"\(strings.Split(i, ":")[0])": "\(strings.Split(i, ":")[1])"
						}
						if len(defaults.additional_labels.external_spire_label) > 0 {
							"\(defaults.additional_labels.external_spire_label)": "\(config.operator_namespace).\(mesh.metadata.name).\(Name)"
						}
					}
				}
				spec: #spire_permission_requests & {
					containers: [
						#sidecar_container_block & {_Name: Name},
						{
							name:  "control"
							image: mesh.spec.images.control
							ports: [{
								name:          "xds"
								containerPort: 50000
							}]
							env: [
								{name: "GM_CONTROL_CMD", value:                "kubernetes"},
								{name: "KUBERNETES_NAMESPACES", value:         strings.Join([mesh.spec.install_namespace]+mesh.spec.watch_namespaces, ",")},
								{name: "KUBERNETES_CLUSTER_LABEL", value:      "greymatter.io/cluster"},
								{name: "KUBERNETES_PORT_NAMES", value:         defaults.proxy_port_name},
								{name: "GM_CONTROL_REDIS_ADDRESS", value:      "\(defaults.redis_host):6379"},
								{name: "GM_CONTROL_XDS_ADS_ENABLED", value:    "true"},
								{name: "GM_CONTROL_XDS_RESOLVE_DNS", value:    "true"},
								{name: "GM_CONTROL_API_HOST", value:           "127.0.0.1:5555"},
								{name: "GM_CONTROL_API_INSECURE", value:       "true"},
								{name: "GM_CONTROL_API_SSL", value:            "false"},
								{name: "GM_CONTROL_API_KEY", value:            "xxx"}, // no longer used, but must be set
								{name: "GM_CONTROL_API_ZONE_NAME", value:      mesh.spec.zone},
								{name: "GM_CONTROL_DIFF_IGNORE_CREATE", value: "true"},
								{name: "GM_CONTROL_CONSOLE_LEVEL", value:      "info"},
							]
							resources:       control_resources
							imagePullPolicy: defaults.image_pull_policy
							securityContext: {
								allowPrivilegeEscalation: false
								capabilities: {drop: ["ALL"]}
							}
						}, // control

						{
							name:  "control-api"
							image: mesh.spec.images.control_api
							ports: [{
								name:          "api"
								containerPort: 5555
							}]
							env: [
								{name: "GM_CONTROL_API_ADDRESS", value:               "0.0.0.0:5555"},
								{name: "GM_CONTROL_API_USE_TLS", value:               "false"},
								{name: "GM_CONTROL_API_ZONE_NAME", value:             mesh.spec.zone},
								{name: "GM_CONTROL_API_ZONE_KEY", value:              mesh.spec.zone},
								{name: "GM_CONTROL_API_DISABLE_VERSION_CHECK", value: "false"},
								{name: "GM_CONTROL_API_PERSISTER_TYPE", value:        "redis"},
								{name: "GM_CONTROL_API_REDIS_MAX_RETRIES", value:     "50"},
								{name: "GM_CONTROL_API_REDIS_RETRY_DELAY", value:     "5s"},
								// later use redis sidecar or external redis, but this keeps bootstrap simple for now
								{name: "GM_CONTROL_API_REDIS_HOST", value: defaults.redis_host},
								{name: "GM_CONTROL_API_REDIS_PORT", value: "6379"}, // local redis in this pod
								{name: "GM_CONTROL_API_REDIS_DB", value:   "0"},
								{name: "GM_CONTROL_API_LOG_LEVEL", value:  "error"},
							]
							resources:       control_api_resources
							imagePullPolicy: defaults.image_pull_policy
							securityContext: {
								allowPrivilegeEscalation: false
								capabilities: {drop: ["ALL"]}
							}
						}, // control_api

					] // containers
					securityContext: {
						runAsNonRoot: true
						seccompProfile: {type: "RuntimeDefault"}
					}
					volumes: #sidecar_volumes + []
					imagePullSecrets: [{name: defaults.image_pull_secret_name}]
					serviceAccountName: Name
				}
			}
		}
	},

	corev1.#ServiceAccount & {
		apiVersion: "v1"
		kind:       "ServiceAccount"
		metadata: {
			name:      Name
			namespace: mesh.spec.install_namespace
		}
	},

	rbacv1.#ClusterRole & {
		apiVersion: "rbac.authorization.k8s.io/v1"
		kind:       "ClusterRole"
		metadata: name: "\(config.operator_namespace)-\(Name)"
		rules: [{
			apiGroups: [""]
			resources: ["pods"]
			verbs: ["get", "list"]
		}]
	},

	rbacv1.#ClusterRoleBinding & {
		apiVersion: "rbac.authorization.k8s.io/v1"
		kind:       "ClusterRoleBinding"
		metadata: {
			name:      "\(config.operator_namespace)-\(Name)-clusterrolebinding"
			namespace: mesh.spec.install_namespace
		}
		subjects: [{
			kind:      "ServiceAccount"
			name:      Name
			namespace: mesh.spec.install_namespace
		}]
		roleRef: {
			kind:     "ClusterRole"
			name:     "\(config.operator_namespace)-\(Name)"
			apiGroup: "rbac.authorization.k8s.io"
		}
	},

	corev1.#Service & {
		apiVersion: "v1"
		kind:       "Service"
		metadata: {
			name:      Name
			namespace: mesh.spec.install_namespace
		}
		spec: {
			selector: "greymatter.io/cluster": Name
			ports: [
				{
					name:       "proxy"
					port:       defaults.ports.default_ingress
					targetPort: defaults.ports.default_ingress
				},
				{
					name:       "control"
					port:       50000
					targetPort: 50000
				},
				{
					name:       "controlapi"
					port:       5555
					targetPort: 5555 // the operator needs direct access gmapi.go#66
				},
			]
		}
	},
]
