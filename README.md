# cronv-automation

Automated pipeline that keeps a periodic CI job cron visualization up to date.
Watches `openshift/release` for schedule changes and regenerates the HTML
visualization automatically.

## How It Works

1. **git-sync** polls `openshift/release@main` every 5 minutes (sparse checkout)
2. On a new commit, it triggers `on-sync.sh` via the exechook mechanism
3. `parse_cron.py` reads the Prow periodics YAML and outputs a `crontab.txt`
4. `cronv` converts `crontab.txt` into an HTML timeline visualization
5. The HTML is copied to the nginx serving path

No manual steps after initial setup.

## Prerequisites

Install these on the target host:

```bash
# Python 3 + PyYAML
sudo dnf install python3 python3-pyyaml   # RHEL/Fedora
# or: pip3 install pyyaml

# cronv (install and copy to system PATH)
go install github.com/takumakanari/cronv/cronv@0.4.5
sudo cp ~/go/bin/cronv /usr/local/bin/

# git-sync v4 (recommended: download binary from GitHub releases)
# https://github.com/kubernetes/git-sync/releases
# Download the linux_amd64 tar, extract, and install:
#   tar xzf git-sync_<version>_linux_amd64.tar.gz
#   sudo cp git-sync /usr/local/bin/
#
# Alternative: build from source
#   go install k8s.io/git-sync@latest
#   sudo cp ~/go/bin/git-sync /usr/local/bin/
```

Verify all binaries are in `/usr/local/bin/` (required for systemd):

```bash
/usr/local/bin/git-sync --help
/usr/local/bin/cronv --help
python3 -c "import yaml; print('PyYAML OK')"
```

## Installation

```bash
# 1. Clone this repo to /opt/cronv-automation
sudo git clone https://github.com/mmnabeel317/cronv-automation.git /opt/cronv-automation

# 2. Create runtime directories
sudo mkdir -p /opt/cronv-automation/{repo,output}

# 3. Make scripts executable
sudo chmod +x /opt/cronv-automation/scripts/*.sh

# 4. Edit the environment config if needed
sudo vi /opt/cronv-automation/config/cronv-automation.env
# At minimum, verify NGINX_HTML_PATH points to your nginx serving directory

# 5. Install and start the systemd service
sudo cp /opt/cronv-automation/systemd/cronv-git-sync.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now cronv-git-sync.service
```

## Configuration

Edit `config/cronv-automation.env` to customize:

| Variable | Default | Description |
|----------|---------|-------------|
| `NGINX_HTML_PATH` | `/var/www/html/crontab.html` | Where nginx serves the HTML |
| `CRONV_DURATION` | `31d` | Timeline window duration |
| `CRONV_TITLE` | `Periodic CI Jobs` | HTML page title |
| `CRONV_WIDTH` | `150` | Table width percentage |
| `GIT_SYNC_PERIOD` | `300s` | How often to check for changes |
| `REPO_URL` | `https://github.com/openshift/release.git` | Repository to watch |
| `REPO_REF` | `main` | Branch to track |
| `AUTOMATION_DIR` | `/opt/cronv-automation` | Base install directory |

After editing, restart the service:

```bash
sudo systemctl restart cronv-git-sync.service
```

## Usage

### Check service status

```bash
sudo systemctl status cronv-git-sync.service
```

### View logs

```bash
journalctl -u cronv-git-sync -f            # follow live
journalctl -u cronv-git-sync --since today  # today's logs
```

### Manual test run

You can test the parser and HTML generation without git-sync:

```bash
# Parse the periodics file from a local clone of openshift/release
python3 /opt/cronv-automation/scripts/parse_cron.py /path/to/release > /tmp/crontab.txt

# Generate HTML
cat /tmp/crontab.txt | cronv \
    --from-date="$(date -u +%Y/%m/%d)" \
    --from-time=00:00 \
    --duration=31d \
    --title='Periodic CI Jobs' \
    -w 150 \
    -o /tmp/crontab.html

# Open in browser
xdg-open /tmp/crontab.html
```

### Force a re-sync

```bash
sudo systemctl restart cronv-git-sync.service
```

This triggers a fresh sync and re-runs the pipeline.

## Troubleshooting

### Service won't start

```bash
# Check for errors
journalctl -u cronv-git-sync -n 50 --no-pager

# Verify git-sync binary is in PATH
which git-sync

# Verify cronv binary is in PATH
which cronv
```

### Parser finds 0 jobs

The parser will log a warning and skip HTML generation to avoid overwriting
a working visualization with a blank page. Check:

```bash
# Verify the sparse checkout contains the periodics file
ls -la /opt/cronv-automation/repo/current/ci-operator/jobs/openshift-eng/ocp-qe-perfscale-ci/

# Test the parser directly
python3 /opt/cronv-automation/scripts/parse_cron.py /opt/cronv-automation/repo/current
```

### HTML not updating

1. Verify the service is running: `systemctl status cronv-git-sync`
2. Check logs for errors: `journalctl -u cronv-git-sync --since '10 min ago'`
3. Verify nginx path is correct in `cronv-automation.env`
4. Check file permissions on the nginx directory

## Repository Structure

```
cronv-automation/
├── README.md                      # This file
├── scripts/
│   ├── parse_cron.py              # YAML -> crontab.txt parser
│   └── on-sync.sh                 # Orchestrator (parse -> cronv -> nginx)
├── config/
│   ├── cronv-automation.env       # Environment configuration
│   └── sparse-checkout            # git sparse-checkout scope
└── systemd/
    └── cronv-git-sync.service     # systemd unit file
```

