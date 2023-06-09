// Manifests for the Catalog pod

package greymatter

import (
	appsv1 "k8s.io/api/apps/v1"
	corev1 "k8s.io/api/core/v1"
	"strings"
)

let Name = "catalog"
catalog: [
	appsv1.#Deployment & {
		apiVersion: "apps/v1"
		kind:       "Deployment"
		metadata: {
			name:      Name
			namespace: mesh.spec.install_namespace
		}
		spec: {
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

						#sidecar_container_block & {_Name: Name, _volume_mounts: [ {
							name:      defaults.mesh_connections_secret
							mountPath: "/etc/proxy/tls/sidecar/connections"
						}]},

						{
							name:  "catalog"
							image: mesh.spec.images.catalog
							ports: [{
								name:          "catalog"
								containerPort: 8080
							}]
							env: [
								{name: "SEED_FILE_PATH", value:    "/app/seed/seed.yaml"},
								{name: "SEED_FILE_FORMAT", value:  "yaml"},
								{name: "CONFIG_SOURCE", value:     "redis"},
								{name: "REDIS_MAX_RETRIES", value: "10"},
								{name: "REDIS_RETRY_DELAY", value: "5s"},
								// later use redis sidecar or external redis, but this keeps bootstrap simple for now
								{name: "REDIS_HOST", value:               defaults.redis_host},
								{name: "REDIS_PORT", value:               "6379"},
								{name: "REDIS_DB", value:                 "0"},
								{name: "MESH_CONNECTIONS_ENABLED", value: "true"},
							]
							resources:       catalog_resources
							imagePullPolicy: defaults.image_pull_policy
							volumeMounts: [
								{
									name:      "catalog-seed"
									mountPath: "/app/seed"
								},
								{
									name:      "greymatter-catalog-config"
									mountPath: "/app/settings.toml"
									subPath:   "settings.toml"
								},
							]
							securityContext: {
								allowPrivilegeEscalation: false
								capabilities: {drop: ["ALL"]}
							}
						},
					]
					securityContext: {
						runAsNonRoot: true
						seccompProfile: {type: "RuntimeDefault"}
					}
					volumes: #sidecar_volumes + [
							{
							name: "catalog-seed"
							configMap: {name: "catalog-seed", defaultMode: 420}
						},
						{
							name: defaults.mesh_connections_secret
							secret: {
								defaultMode: 420
								secretName:  defaults.mesh_connections_secret
								optional:    true
							}
						},
						{
							name: "greymatter-catalog-config"
							configMap: {
								name:     "greymatter-catalog-config"
								optional: true
							}
						},
					]
					imagePullSecrets: [{name: defaults.image_pull_secret_name}]
				}
			}
		}
	},

	corev1.#ConfigMap & {
		apiVersion: "v1"
		kind:       "ConfigMap"
		metadata: {
			name:      "greymatter-catalog-config"
			namespace: mesh.spec.install_namespace
		}
		data: {
			"settings.toml": """
				"""
		}
	},

	corev1.#ConfigMap & {
		apiVersion: "v1"
		kind:       "ConfigMap"
		metadata: {
			name:      "catalog-seed"
			namespace: mesh.spec.install_namespace
		}
		data: {
			"seed.yaml": """
        \(mesh.metadata.name):
          mesh_type: greymatter
          name: \(mesh.spec.display_name)
          sessions:
            default:
              url: \(defaults.xds_host):50000
              zone: \(mesh.spec.zone)
          labels:
            zone_key: \(mesh.spec.zone)
          extensions:
            metrics:
              sessions:
                redis_example:
                  client_type: redis
                  connection_string: redis://127.0.0.1:\(defaults.ports.redis_ingress)
      """
		}
	},

	// the operator needs direct access
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
					name:       "catalog"
					port:       8080
					targetPort: 8080
				},
			]
		}
	},

]
