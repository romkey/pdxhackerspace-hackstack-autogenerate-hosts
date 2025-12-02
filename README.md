# autogenerate-hosts-reverse-proxy

Automatically generate a dnsmasq-compatible hosts file from nginx-proxy-manager's database.

## Features

- Watches the nginx-proxy-manager SQLite database for changes
- Generates dnsmasq hosts configuration automatically
- Supports both simple hostnames and external domain names
- Atomic file writes to prevent partial updates
- Debouncing to avoid regenerating during rapid database changes
- Graceful shutdown handling (SIGTERM/SIGINT)
- Configurable logging levels

## Environment Variables

### Required

| Variable | Description |
|----------|-------------|
| `TARGET_IP` | The IP address to use for all host entries |
| `DOMAIN_NAME` | The internal domain suffix (e.g., `hackerspace.lan`) |
| `EXTERNAL_DOMAIN` | External domain to include (e.g., `example.org`) |
| `DNSMASQ_PATH` | Path where the hosts file will be written |
| `DB_PATH` | Path to the nginx-proxy-manager SQLite database |

### Optional

| Variable | Default | Description |
|----------|---------|-------------|
| `LOCAL_SUFFIX` | `.local` | Suffix to add for mDNS-style names (set to empty to disable) |
| `LOG_LEVEL` | `INFO` | Log verbosity: `DEBUG`, `INFO`, `WARN`, `ERROR` |
| `DEBOUNCE_SECONDS` | `1` | Seconds to wait after database change before regenerating |

## Docker Usage

```bash
docker build -t autogenerate-hosts .

docker run -d \
  -e TARGET_IP=192.168.1.100 \
  -e DOMAIN_NAME=hackerspace.lan \
  -e EXTERNAL_DOMAIN=example.org \
  -e DNSMASQ_PATH=/config/hosts \
  -e DB_PATH=/data/database.sqlite \
  -v /path/to/npm/data:/data:ro \
  -v /path/to/dnsmasq/config:/config \
  autogenerate-hosts
```

## Docker Compose

See `docker-compose.yml` for an example configuration.

## How It Works

1. **Startup**: Reads proxy host entries from the nginx-proxy-manager database
2. **Filtering**: 
   - Includes simple hostnames (no dots): `wiki`, `gitlab`
   - Includes FQDNs ending with `EXTERNAL_DOMAIN`: `wiki.example.org`
   - Excludes other FQDNs: `wiki.otherdomain.com`
3. **Generation**: Creates host entries:
   - Simple hostnames get multiple entries: `192.168.1.100 wiki wiki.hackerspace.lan wiki.local`
   - External domains get single entry: `192.168.1.100 wiki.example.org`
4. **Watching**: Uses inotify to monitor the database file for changes
5. **Debouncing**: Waits for the debounce period after changes before regenerating

## Development

### Project Structure

```
app/
├── generate_hosts.rb       # Main application entry point
├── test_domain_filter.rb   # Unit tests
└── lib/
    ├── config.rb           # Configuration handling
    ├── domain_filter.rb    # Domain filtering logic
    └── hosts_generator.rb  # Hosts file generation
```

### Running Tests

Tests can run on any platform (macOS, Linux) since they don't require inotify:

```bash
cd app
ruby test_domain_filter.rb
```

### Running Locally

Note: The main application requires Linux (inotify). For development on macOS, use Docker.

```bash
export TARGET_IP=192.168.1.100
export DOMAIN_NAME=hackerspace.lan
export EXTERNAL_DOMAIN=example.org
export DNSMASQ_PATH=/tmp/hosts
export DB_PATH=/path/to/database.sqlite

cd app
ruby generate_hosts.rb
```

## CI/CD

This project uses GitHub Actions to automatically:

- **Run tests** on every push and pull request
- **Build and publish** Docker images to GitHub Container Registry (`ghcr.io`)

### Image Tags

| Trigger | Tags |
|---------|------|
| Push to `main` | `latest`, `main`, `<sha>` |
| Tag `v1.2.3` | `1.2.3`, `1.2`, `1`, `<sha>` |
| Pull request | `pr-<number>` (build only, not pushed) |

### Using the Published Image

```bash
docker pull ghcr.io/romkey/pdxhackerspace-hackstack-autogenerate-hosts:latest
```

## License

See [LICENSE](LICENSE) for details.
