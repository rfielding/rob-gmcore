package greymatter

import (
	greymatter "greymatter.io/api"
)

// The below `greymatter.#FilterSecret`'s must be statically defined given the following:
// - The filter field must match the configuration field name in the Listener's `http_filters` object.
// - The path must be accessible through JSON so control can parse accordingly.
// FilterSecrets can be one of 2 types: #PlaintextSecret or #KubernetesSecret. Plaintext secrets should 
// strictly be used for dev and are passthrough. Kubernetes secrets are read from the environment by control
// and injected into the filters configuraiton over the wire.
// For an example of using a secret below, check out the `defaults.edge.oidc.client_secret` or the 
// `defaults.metrics_receiver` plaintext secret.

// Keycloak/OIDC client secret used in the OIDC filter pipeline.
#OIDCSecret: greymatter.#FilterSecret & {
	filter: "gm_oidc-authentication"
	path:   "clientSecret"
}

// Metrics filter external connections supporting the
// health checking system
#MetricsNatsSecret: greymatter.#FilterSecret & {
	filter: "gm_metrics"
	path:   "metrics_receiver.nats_connection_string"
}

#MetricsRedisSecret: greymatter.#FilterSecret & {
	filter: "gm_metrics"
	path:   "metrics_receiver.redis_connection_string"
}

// MetricsFilter AWS Cloudwatch secrets
#MetricsAWSSecretAccessKeySecret: greymatter.#FilterSecret & {
	filter: "gm_metrics"
	path:   "aws_secret_access_key"
}

#MetricsAWSAccessKeyIDSecret: greymatter.#FilterSecret & {
	filter: "gm_metrics"
	path:   "aws_access_key_id"
}

#MetricsAWSSessionTokenSecret: greymatter.#FilterSecret & {
	filter: "gm_metrics"
	path:   "aws_session_token"
}
