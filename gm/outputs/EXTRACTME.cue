// All greymatter config objects for core componenents drawn together
// for simultaneous application

package greymatter

import (
	"encoding/yaml"
	"list"
)

_enable_jwtsecurity: *false | bool
if defaults.jwtsecurity != _|_ {
	_enable_jwtsecurity: defaults.jwtsecurity
}

mesh_configs: list.Concat([
		[ for x in remote_jwks_config if defaults.edge.oidc.enable_remote_jwks {x}],
		redis_config,
		edge_config,
		catalog_config,
		controlensemble_config,
		dashboard_config,
		catalog_entries,
		[ for x in prometheus_config if config.enable_historical_metrics {x}],
		[ for x in jwtsecurity_config if _enable_jwtsecurity {x}],
		[ for x in audits_config if config.enable_audits {x}],
])

redis_listener: redis_listener_object // special because we need to re-apply it when Spire is enabled for every new sidecar

prometheus_mesh_configs: [ for x in prometheus_config if config.enable_historical_metrics {x}] + catalog_entries

edge_configs:              edge_config
dashboard_configs:         dashboard_config
catalog_configs:           catalog_config
controlensemble_configs:   controlensemble_config
prometheus_configs:        prometheus_config
redis_configs:             redis_config
jwtsecurity_configs:       jwtsecurity_config
audits_configs:            audits_config

// for CLI convenience,
// e.g. `cue eval -c ./gm/outputs --out text -e mesh_configs_yaml`
mesh_configs_yaml: yaml.MarshalStream(mesh_configs)

prometheus_mesh_configs_yaml: yaml.MarshalStream(prometheus_mesh_configs)

sidecar_config: #sidecar_config // pass a Name and Port
