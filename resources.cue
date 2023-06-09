package greymatter

import corev1 "k8s.io/api/core/v1"

operator_resources: corev1.#ResourceRequirements & {
	requests: {
		// cpu:    "150m"
		// memory: "1100Mi"
	}
	limits: {
		// memory: "1100Mi"
	}
}

edge_and_sidecar_resources: corev1.#ResourceRequirements & {
	requests: {
		// cpu:    "250m"
		// memory: "615Mi"
	}
	limits: {
		// memory: "615Mi"
	}
}

control_resources: corev1.#ResourceRequirements & {
	requests: {
		// cpu:    "200m"
		// memory: "2000Mi"
	}
	limits: {
		// memory: "2000Mi"
	}
}

control_api_resources: corev1.#ResourceRequirements & {
	requests: {
		// cpu:    "75m"
		// memory: "620Mi"
	}
	limits: {
		// memory: "620Mi"
	}
}

redis_resources: corev1.#ResourceRequirements & {
	requests: {
		// cpu:    "15m"
		// memory: "550Mi"
	}
	limits: {
		// memory: "550Mi"
	}
}

dashboard_resources: corev1.#ResourceRequirements & {
	requests: {
		// cpu:    "10m"
		// memory: "1Gi"
	}
	limits: {
		// memory: "1Gi"
	}
}

catalog_resources: corev1.#ResourceRequirements & {
	requests: {
		// cpu:    "500m"
		// memory: "735Mi"
	}
	limits: {
		// memory: "735Mi"
	}
}

audits_resources: corev1.#ResourceRequirements & {
	requests: {
		// cpu:    "10m"
		// memory: "2Gi"
	}
	limits: {
		// memory: "2Gi"
	}
}

prometheus_resources: corev1.#ResourceRequirements & {
	requests: {
		// cpu:    "500m"
		// memory: "3Gi"
	}
	limits: {
		// memory: "3Gi"
	}
}

vector_resources: corev1.#ResourceRequirements & {
	requests: {
		// cpu:    "750m"
		// memory: "1200Mi"
	}
	limits: {
		// memory: "1200Mi"
	}
}

spire_server_resources: corev1.#ResourceRequirements & {
	requests: {
		// cpu:    "100m"
		// memory: "1Gi"
	}
	limits: {
		// memory: "1Gi"
	}
}

spire_registrar_resources: corev1.#ResourceRequirements & {
	requests: {}
	limits: {}
}

spire_agent_resources: corev1.#ResourceRequirements & {
	requests: {
		// cpu:    "100m"
		// memory: "1Gi"
	}
	limits: {
		// memory: "1Gi"
	}
}

keycloak_resources: corev1.#ResourceRequirements & {
	requests: {
		// cpu:    "200m"
		// memory: "2Gi"
	}
	limits: {
		// memory: "2Gi"
	}
}

keycloak_postgres_resources: corev1.#ResourceRequirements & {
	requests: {
		// cpu:    "50m"
		// memory: "1Gi"
	}
	limits: {
		// memory: "1Gi"
	}
}
