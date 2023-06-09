package greymatter

import (
	appsv1 "k8s.io/api/apps/v1"
	corev1 "k8s.io/api/core/v1"
	"strings"
)

edge: [
	appsv1.#Deployment & {
		apiVersion: "apps/v1"
		kind:       "Deployment"
		metadata: {
			name:      defaults.edge.key
			namespace: mesh.spec.install_namespace
		}
		spec: {
			selector: {
				matchLabels: {"greymatter.io/cluster": defaults.edge.key}
			}
			template: {
				metadata: {
					labels: {
						"greymatter.io/cluster":  defaults.edge.key
						"greymatter.io/workload": "\(config.operator_namespace).\(mesh.metadata.name).\(defaults.edge.key)"
						for i in defaults.additional_labels.all_pods {
							"\(strings.Split(i, ":")[0])": "\(strings.Split(i, ":")[1])"
						}
						if len(defaults.additional_labels.external_spire_label) > 0 {
							"\(defaults.additional_labels.external_spire_label)": "\(config.operator_namespace).\(mesh.metadata.name).\(defaults.edge.key)"
						}
					}
				}
				spec: #spire_permission_requests & {
					containers: [
						#sidecar_container_block & {
							_Name: defaults.edge.key
							_volume_mounts: [
								if (_security_spec.edge.type == "tls" || _security_spec.edge.type == "mtls") {
									{
										name:      "tls-certs"
										mountPath: "/etc/proxy/tls/edge"
									}
								},
								{
									name:      defaults.mesh_connections_secret
									mountPath: "/etc/proxy/tls/edge/connections"
								},
							]
						},
					]
					volumes: #sidecar_volumes + [
							if (_security_spec.edge.type == "tls" || _security_spec.edge.type == "mtls") {
							{
								name: "tls-certs"
								secret: {
									defaultMode: 420
									secretName:  _security_spec.edge.secret_name
								}
							}
						},
						{
							name: defaults.mesh_connections_secret
							secret: {
								defaultMode: 420
								secretName:  defaults.mesh_connections_secret
								optional:    true
							}
						},
					]
					imagePullSecrets: [{name: defaults.image_pull_secret_name}]
				}
			}
		}
	},

	corev1.#Service & {
		apiVersion: "v1"
		kind:       "Service"
		metadata: {
			name:      defaults.edge.key
			namespace: mesh.spec.install_namespace
			if len(defaults.additional_labels.edge_service) > 0 {
				labels: {
					for i in defaults.additional_labels.edge_service {
						"\(strings.Split(i, ":")[0])": "\(strings.Split(i, ":")[1])"
					}
				}
			}
			if len(defaults.edge.annotations.service) > 0 {
				annotations: {
					for i in defaults.edge.annotations.service {
						"\(strings.Split(i, ":")[0])": "\(strings.Split(i, ":")[1])"
					}
				}
			}
		}
		spec: {
			selector: "greymatter.io/cluster": defaults.edge.key
			type: "LoadBalancer"
			ports: [{
				name:       "ingress"
				port:       defaults.ports.edge_ingress
				targetPort: defaults.ports.edge_ingress
			}]
		}
	},
]
