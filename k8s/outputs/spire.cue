// k8s manifests for Spire

package greymatter

import (
	appsv1 "k8s.io/api/apps/v1"
	corev1 "k8s.io/api/core/v1"
	rbacv1 "k8s.io/api/rbac/v1"
)

spire_namespace: [
	corev1.#Namespace & {
		// Starting with this Namespace, these manifests should only apply if we want Spire
		apiVersion: "v1"
		kind:       "Namespace"
		metadata: {
			name: defaults.spire.namespace
			labels: name: "spire"
		}
	},
]

spire_server: [
	corev1.#Service & {
		apiVersion: "v1"
		kind:       "Service"
		metadata: {
			name:      "server"
			namespace: defaults.spire.namespace
		}
		spec: {
			type: "NodePort"
			selector: app: "server"
			ports: [{
				name:       "server"
				protocol:   "TCP"
				port:       8443
				targetPort: 8443
			}]
		}
	},
	appsv1.#StatefulSet & {
		apiVersion: "apps/v1"
		kind:       "StatefulSet"
		metadata: {
			name:      "server"
			namespace: defaults.spire.namespace
			labels: app: "server"
		}
		spec: {
			selector: matchLabels: app: "server"
			serviceName: "server"
			template: {
				metadata: {
					name:      "server"
					namespace: defaults.spire.namespace
					labels: app: "server"
				}
				spec: {
					containers: [{
						name:            "server"
						image:           "gcr.io/spiffe-io/spire-server:1.5.4"
						imagePullPolicy: "IfNotPresent"
						args: [
							"-config",
							"/run/spire/config/server.conf",
						]
						ports: [{
							containerPort: 8443
							name:          "server"
							protocol:      "TCP"
						}]
						livenessProbe: {
							exec: command: [
								"/opt/spire/bin/spire-server",
								"healthcheck",
								"-socketPath=\(defaults.spire.socket_mount_path)/registration.sock",
							]
							failureThreshold:    2
							initialDelaySeconds: 15
							periodSeconds:       60
							timeoutSeconds:      3
						}
						volumeMounts: [{
							name:      "server-socket"
							mountPath: defaults.spire.socket_mount_path
						}, {
							name:      "server-config"
							mountPath: "/run/spire/config"
							readOnly:  true
						}, {
							name:      defaults.spire.ca_secret_name
							mountPath: "/run/spire/ca"
							readOnly:  true
						}, {
							name:      "server-data" // Mounted from PVC
							mountPath: "/run/spire/data"
						}]
						securityContext: {
							allowPrivilegeEscalation: false
							capabilities: {drop: ["ALL"]}
						}
						resources: spire_server_resources
					}, {
						name:            "registrar"
						image:           "gcr.io/spiffe-io/k8s-workload-registrar:1.5.4"
						imagePullPolicy: "IfNotPresent"
						args: [
							"-config",
							"/run/spire/config/registrar.conf",
						]
						ports: [{
							containerPort: 8444
							name:          "registrar"
							protocol:      "TCP"
						}]
						volumeMounts: [{
							name:      "server-config"
							mountPath: "/run/spire/config"
							readOnly:  true
						}, {
							name:      "server-socket"
							mountPath: defaults.spire.socket_mount_path
						}]
						securityContext: {
							allowPrivilegeEscalation: false
							capabilities: {drop: ["ALL"]}
						}
						resources: spire_registrar_resources
					}]
					volumes: [{
						name: "server-socket"
						emptyDir: medium: "Memory"
					}, {
						name: "server-config"
						configMap: {
							name:        "server-config"
							defaultMode: 420
						}
					}, {
						name: defaults.spire.ca_secret_name
						secret: {
							secretName:  defaults.spire.ca_secret_name
							defaultMode: 420
						}
					}]
					serviceAccountName:    "server"
					shareProcessNamespace: true
				}
			}
			volumeClaimTemplates: [{
				apiVersion: "v1"
				kind:       "PersistentVolumeClaim"
				metadata: {
					name:      "server-data"
					namespace: defaults.spire.namespace
				}
				spec: {
					accessModes: [
						"ReadWriteOnce",
					]
					resources: requests: storage: "1Gi"
					volumeMode: "Filesystem"
				}
			}]
		}
	},
	corev1.#ServiceAccount & {
		apiVersion: "v1"
		kind:       "ServiceAccount"
		metadata: {
			name:      "server"
			namespace: defaults.spire.namespace
		}
	},
	rbacv1.#Role & {
		apiVersion: "rbac.authorization.k8s.io/v1"
		kind:       "Role"
		metadata: {
			name:      "server"
			namespace: defaults.spire.namespace
		}
		rules: [
			{
				apiGroups: [""]
				resources: ["configmaps"]
				verbs: ["create", "list", "get", "update", "patch"]
			},
			{
				apiGroups: [""]
				resources: ["events"]
				verbs: ["create"]
			},
		]
	},
	rbacv1.#ClusterRole & {
		apiVersion: "rbac.authorization.k8s.io/v1"
		kind:       "ClusterRole"
		metadata: name: "spire-server"
		rules: [
			{
				apiGroups: [""]
				resources: ["pods", "nodes", "endpoints"]
				verbs: ["get", "list", "watch"]
			},
			{
				apiGroups: [ "authentication.k8s.io"]
				resources: [ "tokenreviews"]
				verbs: [ "get", "create"]
			},
		]
	},
	rbacv1.#RoleBinding & {
		apiVersion: "rbac.authorization.k8s.io/v1"
		kind:       "RoleBinding"
		metadata: {
			name:      "server"
			namespace: defaults.spire.namespace
		}
		roleRef: {
			apiGroup: "rbac.authorization.k8s.io"
			kind:     "Role"
			name:     "server"
		}
		subjects: [{
			kind:      "ServiceAccount"
			name:      "server"
			namespace: defaults.spire.namespace
		}]
	},
	rbacv1.#ClusterRoleBinding & {
		apiVersion: "rbac.authorization.k8s.io/v1"
		kind:       "ClusterRoleBinding"
		metadata: name: "spire-server"
		roleRef: {
			apiGroup: "rbac.authorization.k8s.io"
			kind:     "ClusterRole"
			name:     "spire-server"
		}
		subjects: [{
			kind:      "ServiceAccount"
			name:      "server"
			namespace: defaults.spire.namespace
		}]
	},
	corev1.#ConfigMap & {
		apiVersion: "v1"
		kind:       "ConfigMap"
		metadata: {
			name:      "server-config"
			namespace: defaults.spire.namespace
		}
		data: {
			// https://github.com/spiffe/spire/tree/main/support/k8s/k8s-workload-registrar
			// https://github.com/lucianozablocki/spire-tutorials/tree/k8s-registrar-tutorial/k8s/k8s-workload-registrar#configure-reconcile-mode
			"registrar.conf": #"""
        trust_domain = "\#(defaults.spire.trust_domain)"
        server_socket_path = "\#(defaults.spire.socket_mount_path)/registration.sock"
        cluster = "meshes"
        mode = "reconcile"
        pod_label = "greymatter.io/workload"
        metrics_addr = "0"
        controller_name = "k8s-workload-registrar"
        log_level = "debug"
        log_path = "/dev/stdout"
        """#

			// https://spiffe.io/docs/latest/deploying/spire_server/
			"server.conf": #"""
        server {
          bind_address = "0.0.0.0"
          bind_port = "8443"
          ca_subject = {
            country = ["US"],
            organization = ["Grey Matter"],
            common_name = "Mesh",
          }
          data_dir = "/run/spire/data"
          default_svid_ttl = "1h"
          log_file = "/dev/stdout"
          log_level = "DEBUG"
          trust_domain = "\#(defaults.spire.trust_domain)"
          socket_path = "\#(defaults.spire.socket_mount_path)/registration.sock"
        }
        plugins {
          DataStore "sql" {
            plugin_data {
              database_type = "sqlite3"
              connection_string = "/run/spire/data/datastore.sqlite3"
            }
          }
          NodeAttestor "k8s_psat" {
            plugin_data {
              clusters = {
                "meshes" = {
                  service_account_allow_list = ["spire:agent"]
                  audience = ["server"]
                }
              }
            }
          }
          KeyManager "disk" {
            plugin_data {
              keys_path = "/run/spire/data/keys.json"
            }
          }
          Notifier "k8sbundle" {
            plugin_data {
              namespace = "\#(defaults.spire.namespace)"
              config_map = "server-bundle"
            }
          }
          UpstreamAuthority "disk" {
            plugin_data {
              cert_file_path = "/run/spire/ca/intermediate.crt"
              key_file_path = "/run/spire/ca/intermediate.key"
              bundle_file_path = "/run/spire/ca/root.crt"
            }
          }
        }
        """#
		}
	},
	corev1.#ConfigMap & {
		apiVersion: "v1"
		kind:       "ConfigMap"
		metadata: {
			name:      "server-bundle"
			namespace: defaults.spire.namespace
		}
		data: "bundle.crt": ""
	},
]
