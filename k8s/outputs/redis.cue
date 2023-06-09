// Manifests for the Redis pod

package greymatter

import (
	appsv1 "k8s.io/api/apps/v1"
	corev1 "k8s.io/api/core/v1"
	"strings"
)

let Name = defaults.redis_cluster_name
redis: [
	corev1.#ServiceAccount & {
		apiVersion: "v1"
		kind:       "ServiceAccount"
		metadata: {
			name:      Name
			namespace: mesh.spec.install_namespace
		}
	},

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
						// there are multiple in this ensemble! proxy, control, control-api, and redis

						#sidecar_container_block & {
							_Name: Name
							ports: [{
								name:          "ingress"
								containerPort: defaults.ports.redis_ingress // redis listens on a non-default sidecar port
							}]
						},
						{
							name:  "redis"
							image: mesh.spec.images.redis
							command: ["/app/redis-stack-server/bin/redis-server"]
							args: [
								"--appendonly", "yes",
								"--dir", "/data",
								"--protected-mode", "no",
								"--daemonize", "no",
								"--loadmodule", "/app/redis-stack-server/lib/redisearch.so", "MAXSEARCHRESULTS", "10000", "MAXAGGREGATERESULTS", "10000",
								"--loadmodule", "/app/redis-stack-server/lib/redisgraph.so", "MAX_QUEUED_QUERIES", "25", "TIMEOUT", "1000", "RESULTSET_SIZE", "10000",
								"--loadmodule", "/app/redis-stack-server/lib/redistimeseries.so",
								"--loadmodule", "/app/redis-stack-server/lib/rejson.so",
								"--loadmodule", "/app/redis-stack-server/lib/redisbloom.so",
								"--logLevel", "verbose",
							]
							resources: redis_resources
							ports: [{
								name:          "redis"
								containerPort: 6379 // this port is exposed so the Service (below) can get to it for easy bootstrap
							}]
							imagePullPolicy: defaults.image_pull_policy
							volumeMounts: [
								{
									name:      "\(config.operator_namespace)-gm-redis-append-dir-\(mesh.metadata.name)"
									mountPath: "/data"
								},
							]
							securityContext: {
								allowPrivilegeEscalation: false
								capabilities: {drop: ["ALL"]}
							}
						}, // redis
					] // containers
					securityContext: {
						runAsUser:           1001
						fsGroup:             1001
						fsGroupChangePolicy: "OnRootMismatch"
						runAsNonRoot:        true
						seccompProfile: {type: "RuntimeDefault"}
					}
					volumes: #sidecar_volumes
					imagePullSecrets: [{name: defaults.image_pull_secret_name}]
					serviceAccountName: Name
				}
			}
			volumeClaimTemplates: [
				{
					apiVersion: "v1"
					kind:       "PersistentVolumeClaim"
					metadata: name: "\(config.operator_namespace)-gm-redis-append-dir-\(mesh.metadata.name)"
					spec: {
						accessModes: ["ReadWriteOnce"]
						resources: requests: storage: "1Gi"
						volumeMode: "Filesystem"
					}
				},
			]
		}
	},

	// to avoid static configuration during bootstrap, grant direct access to redis
	// later, use Redis' sidecar
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
					name:       "redis"
					port:       6379
					targetPort: 6379
				},
			]
		}
	},
]
