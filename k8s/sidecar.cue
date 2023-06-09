package greymatter

import (
	corev1 "k8s.io/api/core/v1"
)

// Note that this container block needs to go in `containers`, and refers to a
// spire-socket volume that must be configured separately (see below)
#sidecar_container_block: {
	_Name: string
	_volume_mounts: [...]

	name:  "sidecar18"
	image: mesh.spec.images.proxy
	ports: [...corev1.#ContainerPort] | *[
		{
			name:          defaults.proxy_port_name
			containerPort: defaults.ports.default_ingress
		},
		{
			name:          defaults.metrics_port_name
			containerPort: defaults.ports.metrics
		},
	]
	env: [
		{name: "XDS_CLUSTER", value:          _Name},
		{name: "ENVOY_ADMIN_PORT", value:     "\(defaults.ports.envoy_admin)"},
		{name: "ENVOY_ADMIN_LOG_PATH", value: "/dev/stdout"},
		{name: "PROXY_DYNAMIC", value:        "true"},
		{name: "XDS_ZONE", value:             mesh.spec.zone},
		{name: "XDS_HOST", value:             defaults.xds_host},
		{name: "XDS_PORT", value:             "50000"},
		if _security_spec.internal.type == "spire" {
			{name: "SPIRE_PATH", value: "\(defaults.spire.socket_mount_path)/agent.sock"}
		},
	]
	if defaults.allow_multi_sidecar == true {
		args: ["./gm-proxy", "-c", "config.yaml", "--drain-time-s", "20", "--use-dynamic-base-id"]
	}
	resources:       edge_and_sidecar_resources
	volumeMounts:    #sidecar_volume_mounts + _volume_mounts
	imagePullPolicy: defaults.image_pull_policy
	securityContext: {
		allowPrivilegeEscalation: false
		capabilities: {drop: ["ALL"]}
	}
}

#sidecar_volume_mounts: {
	if _security_spec.internal.type == "spire" {
		[{
			name:      "spire-socket"
			mountPath: defaults.spire.socket_mount_path
		}]
	}
	if (_security_spec.edge.type == "tls" || _security_spec.edge.type == "mtls") && !(_security_spec.internal.type == "spire") {
		[{
			name:      "internal-tls-certs"
			mountPath: "/etc/proxy/tls/sidecar/"
		}]
	}
	[...]
}

#sidecar_volumes: {
	if _security_spec.internal.type == "spire" {
		[{
			name: "spire-socket"
			hostPath: {
				path: defaults.spire.socket_mount_path
				type: "DirectoryOrCreate"
			}
		}]
	}
	if (_security_spec.edge.type == "tls" || _security_spec.edge.type == "mtls") && !(_security_spec.internal.type == "spire") {
		[{
			name: "internal-tls-certs"
			secret: {
				defaultMode: 420
				secretName:  [
						if _security_spec.edge.secret_name != _security_spec.internal.manual.secret_name {_security_spec.internal.manual.secret_name},
						if _security_spec.edge.secret_name == _security_spec.internal.manual.secret_name {_security_spec.edge.secret_name},
				][0]
			}
		}]
	}
	[...]
}

#spire_permission_requests: {
	if _security_spec.internal.type == "spire" {
		hostPID: true
	}
	...
}
