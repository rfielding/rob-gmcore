CATALOG_ENTRY_SCHEMA={
    "type": "object",
    "properties": {
        "mesh_id": {"type": "string"},
        "service_id": {"type": "string"},
        "name": {"type": "string"},
        "api_endpoint": {"type": "string" },
        "description": {"type": "string" },
        "enable_instance_metrics": {"type": "boolean" },
        "enable_historical_metrics": {"type": "boolean" },
        "business_impact": {"type": "string" },
        "version": {"type": "string" },
        "owner": {"type": "string" },
        "capability": {"type": "string" },
    },
    "required": ["mesh_id", "service_id", "name"]
}

CLUSTER_SCHEMA={
    "type": "object",
    "properties": {
        "cluster_key": {"type": "string"},
        "name": {"type": "string"},
        "instances":{ "type": "array"},
        "zone_key": {"type": "string"},
        "ssl_config": {"type": "object"}
    },
    "required": ["cluster_key", "name", "instances"]
}

LISTENER_SCHEMA={
    "type": "object",
    "properties": {
        "name": {"type": "string"},
        "listener_key": {"type": "string"},
        "ip":{ "type": "string"},
        "port":{ "type": "number"},
        "domain_keys": {"type": "array" },
        "active_network_filters":{"type": "array"},
        "zone_key": {"type": "string"}
    },
    "required": ["listener_key", "name", "domain_keys"]
}

DOMAIN_SCHEMA={
    "type": "object",
    "properties": {
        "name": {"type": "string"},
        "domain_key": {"type": "string"},
        "port":{ "type": "number"},
        "zone_key": {"type": "string"},
        "ssl_config": {"type": "object"}
    },
    "required": ["domain_key", "name", "zone_key", "port"]
}

PROXY_SCHEMA={
    "type": "object",
    "properties": {
        "name": {"type": "string"},
        "proxy_key": {"type": "string"},
        "port":{ "type": "number"},
        "domain_keys": {"type": "array"},
        "listener_keys": {"type": "array"},
        "filters": {"type": "object"},
        "zone_key": {"type": "string"},
    },
    "required": ["proxy_key", "domain_keys", "listener_keys", "name", "zone_key"]
}

ROUTE_SCHEMA={
    "type": "object",
    "properties": {
        "route_key": {"type": "string"},
        "domain_key": {"type": "string"},
        "zone_key": {"type": "string"},
        "rules": {"type": "array"},
        "route_match": {"type": "object"},
        "filter_configs": {"type": "object"},
        "redirects": {"type": "array"},
    },
    "required": ["route_key", "domain_key", "zone_key", "rules"]
}

HOST_PORT_SCHEMA={
    "type":"object",
    "proporties": {
        "host": {"type": "string"},
        "port": {"type": "number"}
    },
    "required": ["host", "port"]
}
