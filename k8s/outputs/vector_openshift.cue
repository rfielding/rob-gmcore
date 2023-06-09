package greymatter

import (
	rbacv1 "k8s.io/api/rbac/v1"
)

openshift_vector_scc_bindings: [
	rbacv1.#RoleBinding & {
		apiVersion: "rbac.authorization.k8s.io/v1"
		kind:       "RoleBinding"
		metadata: {
			name:      "\(config.operator_namespace)-vector-scc"
			namespace: mesh.spec.install_namespace
		}
		roleRef: {
			apiGroup: "rbac.authorization.k8s.io"
			kind:     "ClusterRole"
			name:     "\(config.operator_namespace)-vector-scc"
		}
		subjects: [{
			kind:      "ServiceAccount"
			name:      "greymatter-audit-agent"
			namespace: mesh.spec.install_namespace
		}]
	},
]

openshift_vector_scc: [
	{
		apiVersion: "security.openshift.io/v1"
		kind:       "SecurityContextConstraints"
		metadata: {
			annotations: {
				"include.release.openshift.io/self-managed-high-availability": "true"
				"kubernetes.io/description":                                   "Customized policy for Vector to enable hostPath volumes."
				"release.openshift.io/create-only":                            "true"
			}
			name: "vector-scc"
		}
		allowHostDirVolumePlugin: true
		allowHostIPC:             true
		allowHostNetwork:         false
		allowHostPID:             true
		allowHostPorts:           false
		allowPrivilegeEscalation: false
		allowPrivilegedContainer: false
		allowedCapabilities:      null
		allowedUnsafeSysctls:     null
		defaultAddCapabilities:   null
		fsGroup: type: "RunAsAny"
		groups: []
		priority:               null
		readOnlyRootFilesystem: true
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
			name: "\(config.operator_namespace)-vector-scc"
		}
		rules: [{
			apiGroups: ["security.openshift.io"]
			resourceNames: ["vector-scc"]
			resources: ["securitycontextconstraints"]
			verbs: ["use"]
		}]
	},
]
