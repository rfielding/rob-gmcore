// k8s manifests for Vector
package greymatter

import (
	corev1 "k8s.io/api/core/v1"
	rbacv1 "k8s.io/api/rbac/v1"
)

// role_bindings are applied at operator creation time so 
// users don't need to make them for pre-defined core
// filter secrets.
role_bindings: [
	corev1.#Namespace & {
		apiVersion: "v1"
		kind:       "Namespace"
		metadata: {
			labels: name: mesh.spec.install_namespace
			name: mesh.spec.install_namespace
		}
	},

	rbacv1.#ClusterRole & {
		apiVersion: "rbac.authorization.k8s.io/v1"
		kind:       "Role"
		metadata: {
			namespace: mesh.spec.install_namespace
			name:      "secret-name-gm-control-role"
		}
		rules: [{
			apiGroups: [""]
			resourceNames: ["greymatter-oidc-provider"]
			resources: ["secrets"]
			verbs: ["get"]
		}]
	},

	rbacv1.#ClusterRoleBinding & {
		apiVersion: "rbac.authorization.k8s.io/v1"
		kind:       "RoleBinding"
		metadata: {
			name:      "secret-name-gm-control-role-binding"
			namespace: mesh.spec.install_namespace
		}
		subjects: [{
			kind:      "ServiceAccount"
			name:      "controlensemble"
			namespace: mesh.spec.install_namespace
		}]
		roleRef: {
			kind:     "Role"
			name:     "secret-name-gm-control-role"
			apiGroup: "rbac.authorization.k8s.io"
		}
	},
]
