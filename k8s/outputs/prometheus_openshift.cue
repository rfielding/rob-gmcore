package greymatter

import (
	rbacv1 "k8s.io/api/rbac/v1"
)

openshift_prometheus_scc: [
	{
		apiVersion: "security.openshift.io/v1"
		kind:       "SecurityContextConstraints"
		metadata: {
			annotations: {
				"include.release.openshift.io/self-managed-high-availability": "true"
				"kubernetes.io/description":                                   "Customized policy for Redis to enable fsGroup volumes."
				"release.openshift.io/create-only":                            "true"
			}
			name: "prometheus-scc"
		}
		allowHostDirVolumePlugin: false
		allowHostIPC:             false
		allowHostNetwork:         false
		allowHostPID:             false
		allowHostPorts:           false
		allowPrivilegeEscalation: false
		allowPrivilegedContainer: false
		allowedCapabilities:      null
		allowedUnsafeSysctls:     null
		defaultAddCapabilities:   null
		fsGroup: type: "RunAsAny"
		groups: []
		priority:               null
		readOnlyRootFilesystem: false
		requiredDropCapabilities: [ "KILL", "MKNOD", "SETUID", "SETGID"]
		runAsUser: type:          "RunAsAny"
		seLinuxContext: type:     "MustRunAs"
		supplementalGroups: type: "RunAsAny"
		users: []
		volumes: [
			"hostPath",
			"configMap",
			"downwardAPI",
			"emptyDir",
			"persistentVolumeClaim",
			"projected",
			"secret",
		]
	},
	rbacv1.#ClusterRole & {
		apiVersion: "rbac.authorization.k8s.io/v1"
		kind:       "ClusterRole"
		metadata: {
			annotations: {
				"include.release.openshift.io/self-managed-high-availability": "true"
				"rbac.authorization.kubernetes.io/autoupdate":                 "true"
			}
			name: "\(config.operator_namespace)-prometheus-scc"
		}
		rules: [{
			apiGroups: ["security.openshift.io"]
			resourceNames: ["prometheus-scc"]
			resources: ["securitycontextconstraints"]
			verbs: ["use"]
		}]
	},
	rbacv1.#ClusterRoleBinding & {
		apiVersion: "rbac.authorization.k8s.io/v1"
		kind:       "ClusterRoleBinding"
		metadata: {
			name: "\(config.operator_namespace)-prometheus-scc"
		}
		roleRef: {
			apiGroup: "rbac.authorization.k8s.io"
			kind:     "ClusterRole"
			name:     "prometheus-scc"
		}
		subjects: [{
			kind:      "ServiceAccount"
			name:      "prometheus"
			namespace: mesh.spec.install_namespace
		}]
	},
]
