// k8s manifests for operator

package greymatter

import (
	appsv1 "k8s.io/api/apps/v1"
	corev1 "k8s.io/api/core/v1"
	rbacv1 "k8s.io/api/rbac/v1"
)

_git_remote: string | *"git@github.com:greymatter-io/greymatter-core.git" @tag(git_remote,type=string)

operator_namespace: [
	corev1.#Namespace & {
		apiVersion: "v1"
		kind:       "Namespace"
		metadata: {
			labels: name: config.operator_namespace
			name: config.operator_namespace
		}
	},
]

// CI requires "IfNotPresent" (and sets it with this tag) but Always is safer for development
OperatorPullPolicy: string | *"Always" @tag(operator_pull_policy)

operator_sts: [
	appsv1.#StatefulSet & {
		apiVersion: "apps/v1"
		kind:       "StatefulSet"
		metadata: {
			labels: name: "greymatter-operator"
			name:      "greymatter-operator"
			namespace: config.operator_namespace
		}
		spec: {
			serviceName: "greymatter-operator"
			replicas:    1
			selector: matchLabels: name: "greymatter-operator"
			template: {
				metadata: labels: name: "greymatter-operator"
				spec: {
					containers: [{
						env: [
							if config.debug {
								name: "BUGSNAG_API_TOKEN"
								valueFrom: {
									secretKeyRef: {
										name:     "bugsnag-api-token"
										key:      "token"
										optional: true
									}
								}
							},
							{
								name:  "SSH_KNOWN_HOSTS"
								value: "/app/.ssh/known_hosts"
							},
						]
						if !config.debug {
							// command: ["sleep"] // DEBUG
							// args: ["30000"]
							command: [
								"/app/operator",
							]
							if !config.test {
								args: [
									"-repo", _git_remote,
									"-sshPrivateKeyPath", "/app/.ssh/ssh-private-key",
									"-branch", "main",
								]
							}
							livenessProbe: {
								httpGet: {
									path: "/healthz"
									port: 8081
								}
								initialDelaySeconds: 120
								periodSeconds:       20
							}
							imagePullPolicy: OperatorPullPolicy
						}
						if config.debug {
							command: [
								"/app/dlv",
							]
							args: [
								"--listen=:2345",
								"--headless=true",
								"--log=true",
								"--log-output=debugger,debuglineerr,gdbwire,lldbout,rpc",
								"--accept-multiclient",
								"--api-version=2",
								"exec",
								"--continue",
								"/app/operator",
								"--",
								"-repo", _git_remote,
								"-sshPrivateKeyPath", "/app/.ssh/ssh-private-key",
								"-branch", "main",
							]
							imagePullPolicy: "Always"
						}
						image: defaults.images.operator
						name:  "operator"
						ports: [{
							containerPort: 9443
							name:          "webhook-server"
							protocol:      "TCP"
						}]
						readinessProbe: {
							httpGet: {
								path: "/readyz"
								port: 8081
							}
							initialDelaySeconds: 30
							periodSeconds:       10
						}
						resources: operator_resources
						volumeMounts: [
							{
								mountPath: "/tmp/k8s-webhook-server/serving-certs"
								name:      "webhook-cert"
								readOnly:  true
							},
							{
								name:      "overrides-cue"
								mountPath: "/app/core/overrides.cue"
								subPath:   "overrides.cue"
							},
							{
								name:      "greymatter-core-repo"
								readOnly:  true
								mountPath: "/app/.ssh"
							},
						]
						securityContext: {
							allowPrivilegeEscalation: false
							capabilities: {drop: ["ALL"]}
						}
					}]
					securityContext: {
						runAsNonRoot: true
						seccompProfile: {type: "RuntimeDefault"}
					}
					imagePullSecrets: []
					serviceAccountName:            "greymatter-operator"
					terminationGracePeriodSeconds: 10
					volumes: [
						{
							name: "webhook-cert"
							secret: {
								defaultMode: 420
								items: [{
									key:  "tls.crt"
									path: "tls.crt"
								}, {
									key:  "tls.key"
									path: "tls.key"
								}]
								secretName: "gm-webhook-cert"
							}
						},
						{
							name: "overrides-cue"
							configMap: {name: "overrides-cue"}
						},
						{
							name: "greymatter-core-repo"
							secret: {
								defaultMode: 288
								secretName:  "greymatter-core-repo"
							}
						},
					]
				}
			}
		}
	},
]

operator_k8s: [

	// This ConfigMap is so flags passed to cue eval will have an effect on CUE
	// applied at runtime so the integration tests can manipulate things without gitops
	corev1.#ConfigMap & {
		apiVersion: "v1"
		kind:       "ConfigMap"
		metadata: {
			name:      "overrides-cue"
			namespace: config.operator_namespace
		}
		data: {
			"overrides.cue": """
      package greymatter
      config: {
        spire: \(_security_spec.internal.type == "spire")
        openshift: \(config.openshift)
        enable_historical_metrics: \(config.enable_historical_metrics)
        auto_copy_image_pull_secret: \(config.auto_copy_image_pull_secret)
      }
      """
		}
	},

	corev1.#ServiceAccount & {
		apiVersion: "v1"
		imagePullSecrets: [{
			name: "greymatter-image-pull"
		}]
		kind: "ServiceAccount"
		metadata: {
			name:      "greymatter-operator"
			namespace: config.operator_namespace
		}
	},

	rbacv1.#Role & {
		apiVersion: "rbac.authorization.k8s.io/v1"
		kind:       "Role"
		metadata: {
			name:      "gm-leader-election-role"
			namespace: config.operator_namespace
		}
		rules: [{
			apiGroups: [
				"",
			]
			resources: [
				"configmaps",
			]
			verbs: [
				"get",
				"list",
				"watch",
				"create",
				"update",
				"patch",
				"delete",
			]
		}, {
			apiGroups: [
				"coordination.k8s.io",
			]
			resources: [
				"leases",
			]
			verbs: [
				"get",
				"list",
				"watch",
				"create",
				"update",
				"patch",
				"delete",
			]
		}, {
			apiGroups: [
				"",
			]
			resources: [
				"events",
			]
			verbs: [
				"create",
				"patch",
			]
		}]
	},

	rbacv1.#ClusterRole & {
		apiVersion: "rbac.authorization.k8s.io/v1"
		kind:       "ClusterRole"
		metadata: name: "\(config.operator_namespace)-gm-operator-role"
		rules: [{
			apiGroups: [
				"apps",
			]
			resources: [
				"deployments",
				"statefulsets",
			]
			verbs: [
				"watch",
				"get",
				"list",
				"create",
				"update",
				"delete",
			]
		}, {
			apiGroups: [
				"apps",
			]
			resources: [
				"deployments/finalizers",
				"statefulsets/finalizers",
			]
			verbs: [
				"update",
			]
		}, {
			apiGroups: [
				"",
			]
			resources: [
				"configmaps",
				"secrets",
				"serviceaccounts",
				"services",
			]
			verbs: [
				"get",
				"create",
				"update",
				"patch",
				"delete",
			]
		}, {
			apiGroups: [
				"rbac.authorization.k8s.io",
			]
			resources: [
				"clusterrolebindings",
				"clusterroles",
			]
			verbs: [
				"get",
				"create",
				"update",
			]
		}, {
			apiGroups: [
				"",
			]
			resources: [
				"pods",
			]
			verbs: [
				"list",
				"update",
			]
		}, {
			apiGroups: [
				"networking.k8s.io",
			]
			resources: [
				"ingresses",
			]
			verbs: [
				"get",
				"create",
				"update",
			]
		}, {
			apiGroups: [
				"config.openshift.io",
			]
			resources: [
				"ingresses",
			]
			verbs: [
				"list",
			]
		}, {
			apiGroups: [
				"",
			]
			resources: [
				"namespaces",
			]
			verbs: [
				"get",
				"create",
			]
		}, {
			apiGroups: [
				"apps",
			]
			resources: [
				"daemonsets",
			]
			verbs: [
				"get",
				"create",
				"update",
			]
		}, {
			apiGroups: [
				"rbac.authorization.k8s.io",
			]
			resources: [
				"roles",
				"rolebindings",
			]
			verbs: [
				"get",
				"create",
				"update",
			]
		}, {
			apiGroups: [
				"",
			]
			resources: [
				"configmaps",
			]
			verbs: [
				"list",
			]
		}, {
			apiGroups: [
				"authentication.k8s.io",
			]
			resources: [
				"tokenreviews",
			]
			verbs: [
				"get",
				"create",
			]
		}, {
			apiGroups: [
				"",
			]
			resources: [
				"nodes",
				"nodes/proxy",
				"pods",
			]
			verbs: [
				"get",
				"list",
				"watch",
			]
		}, {
			apiGroups: ["security.openshift.io"]
			resources: ["securitycontextconstraints"]
			verbs: ["use"]
		}]
	},

	corev1.#Secret & {// the values here get filled in programmatically by the operator
		apiVersion: "v1"
		data: {
			"tls.crt": ''
			"tls.key": ''
		}
		kind: "Secret"
		metadata: {
			name:      "gm-webhook-cert"
			namespace: config.operator_namespace
		}
	},

	rbacv1.#RoleBinding & {
		apiVersion: "rbac.authorization.k8s.io/v1"
		kind:       "RoleBinding"
		metadata: {
			name:      "gm-leader-election-rolebinding"
			namespace: config.operator_namespace
		}
		roleRef: {
			apiGroup: "rbac.authorization.k8s.io"
			kind:     "Role"
			name:     "gm-leader-election-role"
		}
		subjects: [{
			kind:      "ServiceAccount"
			name:      "greymatter-operator"
			namespace: config.operator_namespace
		}]
	},

	// This ClusterRoleBinding, apart from its normal duties, is also the owner of most operator-created
	// resources because it has cluster scope and the CRD (the previous owner) is deprecated.
	rbacv1.#ClusterRoleBinding & {
		apiVersion: "rbac.authorization.k8s.io/v1"
		kind:       "ClusterRoleBinding"
		metadata: name: "\(config.operator_namespace)-gm-operator-rolebinding"
		roleRef: {
			apiGroup: "rbac.authorization.k8s.io"
			kind:     "ClusterRole"
			name:     "\(config.operator_namespace)-gm-operator-role"
		}
		subjects: [{
			kind:      "ServiceAccount"
			name:      "greymatter-operator"
			namespace: config.operator_namespace
		}]
	},
]
