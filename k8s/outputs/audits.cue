// k8s manifests for Audits App

package greymatter

import (
	appsv1 "k8s.io/api/apps/v1"
	"strings"
)

let Name = "audits"

audits: [
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
						#sidecar_container_block & {_Name: Name},
						{
							name:            Name
							image:           defaults.images.audits
							imagePullPolicy: defaults.image_pull_policy
							ports: [{
								containerPort: 5000
							}]
							env: [{
								name:  "BASE_PATH"
								value: "/services/audits"
							}, {
								name:  "ES_INDEX"
								value: defaults.audits.query_index
							}, {
								name:  "ES_EDGE_TOPIC"
								value: defaults.edge.key
							}, {
								name:  "TARGET_PRODUCT"
								value: "gm"
							}, {
								name: "ES_USER"
								valueFrom: {
									secretKeyRef: {
										name: defaults.audits.elasticsearch_secret
										key:  "elasticsearch_username"
									}
								}
							}, {
								name: "ES_PASSWORD"
								valueFrom: {
									secretKeyRef: {
										name: defaults.audits.elasticsearch_secret
										key:  "elasticsearch_password"
									}
								}
							}, {
								// Required for upstream requests to Elasticsearch
								// https://app.shortcut.com/grey-matter/story/31682/audit-app-es-egress-config-sets-host-header-unsupported-in-envoy-1-24-0
								name:  "ES_HOST"
								value: defaults.audits.elasticsearch_host
							}]
							resources: audits_resources
						},
					]
					volumes: #sidecar_volumes
					imagePullSecrets: [{
						name: "greymatter-image-pull"
					}]
				}
			}
		}
	},
]
