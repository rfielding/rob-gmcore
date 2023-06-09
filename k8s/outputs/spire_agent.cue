package greymatter

import (
	appsv1 "k8s.io/api/apps/v1"
	corev1 "k8s.io/api/core/v1"
	rbacv1 "k8s.io/api/rbac/v1"
)

spire_agent: [

	appsv1.#DaemonSet & {
		apiVersion: "apps/v1"
		kind:       "DaemonSet"
		metadata: {
			name:      "agent"
			namespace: defaults.spire.namespace
			labels: app: "agent"
		}
		spec: {
			selector: matchLabels: app: "agent"
			template: {
				metadata: {
					namespace: defaults.spire.namespace
					labels: app: "agent"
				}
				spec: {
					initContainers: [{
						name:            "init-server"
						image:           "gcr.io/spiffe-io/wait-for-it"
						imagePullPolicy: "IfNotPresent"
						args: [
							"-t",
							"30",
							"server:8443",
						]
						// securityContext: {
						// 	allowPrivilegeEscalation: false
						// 	capabilities: {drop: ["ALL"]}
						// }
						resources: {}
					}]
					containers: [{
						name:            "agent"
						image:           "gcr.io/spiffe-io/spire-agent:1.5.4"
						imagePullPolicy: "IfNotPresent"
						args: [
							"-config",
							"/run/spire/config/agent.conf",
						]
						livenessProbe: {
							exec: command: [
								"/opt/spire/bin/spire-agent",
								"healthcheck",
								"-socketPath",
								"\(defaults.spire.socket_mount_path)/agent.sock",
							]
							failureThreshold:    2
							initialDelaySeconds: 15
							periodSeconds:       60
							timeoutSeconds:      3
						}
						volumeMounts: [{
							name:      "agent-config"
							mountPath: "/run/spire/config"
							readOnly:  true
						}, {
							name:      "agent-socket"
							mountPath: defaults.spire.socket_mount_path
						}, {
							name:      "server-bundle"
							mountPath: "/run/spire/bundle"
							readOnly:  true
						}, {
							name:      "agent-token"
							mountPath: "/run/spire/token"
						}]
						// securityContext: {
						// 	allowPrivilegeEscalation: false
						// 	capabilities: {drop: ["ALL"]}
						// }
						resources: spire_agent_resources
					}]
					// securityContext: {
					// 	runAsNonRoot: true
					// 	seccompProfile: {type: "RuntimeDefault"}
					// }
					volumes: [{
						name: "agent-config"
						configMap: {
							defaultMode: 420
							name:        "agent-config"
						}
					}, {
						name: "agent-socket"
						hostPath: {
							path: defaults.spire.socket_mount_path
							type: "DirectoryOrCreate"
						}
					}, {
						name: "server-bundle"
						configMap: {
							defaultMode: 420
							name:        "server-bundle"
						}
					}, {
						name: "agent-token"
						projected: {
							defaultMode: 420
							sources: [{
								serviceAccountToken: {
									audience:          "server"
									expirationSeconds: 7200
									path:              "agent"
								}
							}]
						}
					}]
					serviceAccountName: "agent"
					dnsPolicy:          "ClusterFirstWithHostNet"
					hostNetwork:        true
					hostPID:            true
				}
			}
		}
	},

	corev1.#ServiceAccount & {
		apiVersion: "v1"
		kind:       "ServiceAccount"
		metadata: {
			name:      "agent"
			namespace: defaults.spire.namespace
		}
	},

	rbacv1.#ClusterRole & {
		apiVersion: "rbac.authorization.k8s.io/v1"
		kind:       "ClusterRole"
		metadata: name: "spire-agent"
		rules: [{
			apiGroups: [
				"",
			]
			resources: [
				"pods",
				"nodes",
				"nodes/proxy",
			]
			verbs: [
				"get",
				"list",
			]
		}]
	},

	rbacv1.#ClusterRoleBinding & {
		apiVersion: "rbac.authorization.k8s.io/v1"
		kind:       "ClusterRoleBinding"
		metadata: name: "spire-agent"
		roleRef: {
			apiGroup: "rbac.authorization.k8s.io"
			kind:     "ClusterRole"
			name:     "spire-agent"
		}
		subjects: [{
			kind:      "ServiceAccount"
			name:      "agent"
			namespace: defaults.spire.namespace
		}]
	},
	corev1.#ConfigMap & {
		apiVersion: "v1"
		kind:       "ConfigMap"
		metadata: {
			name:      "agent-config"
			namespace: defaults.spire.namespace
		}
		data: "agent.conf": #"""
      agent {
        data_dir = "/run/spire"
        log_level = "INFO"
        server_address = "server"
        server_port = "8443"
        socket_path = "\#(defaults.spire.socket_mount_path)/agent.sock"
        trust_bundle_path = "/run/spire/bundle/bundle.crt"
        trust_domain = "\#(defaults.spire.trust_domain)"
      }
      plugins {
        NodeAttestor "k8s_psat" {
          plugin_data {
            cluster = "meshes"
            token_path = "/run/spire/token/agent"
          }
        }
        KeyManager "memory" {
          plugin_data {
          }
        }
        WorkloadAttestor "k8s" {
          plugin_data {
            skip_kubelet_verification = true
          }
        }
      }
      """#
	},
]
