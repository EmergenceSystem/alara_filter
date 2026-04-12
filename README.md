# alara_filter
[![License](https://img.shields.io/badge/license-Apache%202.0-blue.svg)](LICENSE.md)

An [em_filter](https://hex.pm/packages/em_filter) agent that exposes the [ALARA](https://hex.pm/packages/alara) distributed entropy pool as an [Emergence](https://github.com/EmergenceSystem/em_disco) agent.

## Actions

Send a JSON-encoded action as the query value. All parameters are optional.

| Action | Parameters | Default | Returns |
|---|---|---|---|
| `generate_random_bytes` | `n` | 32 | base64-encoded random bytes |
| `generate_random_bits` | `n` | 64 | string of 0/1 characters |
| `generate_random_int` | `n_bits` | 128 | non-negative integer |
| `get_nodes` | — | — | PIDs of local entropy workers |
| `get_cluster_nodes` | — | — | local workers + remote node statuses |

Default action when no `action` field is present: `generate_random_bytes` with `n=32`.

## Usage

**Via curl (direct to em_disco):**

```bash
# 32 random bytes (default)
curl -X POST http://localhost:8080/query \
  -H "Content-Type: application/json" \
  -d '{"value": "alara", "capabilities": ["alara"]}'

# 64 random bytes
curl -X POST http://localhost:8080/query \
  -H "Content-Type: application/json" \
  -d '{"value": "{\"action\":\"generate_random_bytes\",\"n\":64}", "capabilities": ["alara"]}'

# 128 random bits
curl -X POST http://localhost:8080/query \
  -H "Content-Type: application/json" \
  -d '{"value": "{\"action\":\"generate_random_bits\",\"n\":128}", "capabilities": ["alara"]}'

# Random integer (256-bit entropy)
curl -X POST http://localhost:8080/query \
  -H "Content-Type: application/json" \
  -d '{"value": "{\"action\":\"generate_random_int\",\"n_bits\":256}", "capabilities": ["alara"]}'

# Cluster view
curl -X POST http://localhost:8080/query \
  -H "Content-Type: application/json" \
  -d '{"value": "{\"action\":\"get_cluster_nodes\"}", "capabilities": ["alara"]}'
```

**Via Erlang shell:**

```erlang
emquest_cli:query(<<"alara">>).
emquest_cli:query(<<"{\"action\":\"get_cluster_nodes\"}">>).
emquest_cli:query(<<"{\"action\":\"generate_random_int\",\"n_bits\":512}">>).
```

## Installation

```bash
git clone https://github.com/EmergenceSystem/alara_filter.git
cd alara_filter
rebar3 shell --apps alara_filter
```

Requires `em_disco` running on `localhost:8080` (configured in `emergence.conf`).

## Capabilities

`search`, `query`, `alara`, `entropy`, `random`, `erlang`, `distributed`

## License

Apache 2.0 — see [LICENSE.md](LICENSE.md).
