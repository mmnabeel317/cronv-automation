#!/usr/bin/env python3
"""Parse openshift/release periodics YAML into cronv-compatible crontab format.

Reads a generated Prow periodics YAML file and outputs
a crontab-format file grouped by OCP version, suitable for piping into cronv.

Usage:
    python3 parse_cron.py /path/to/synced/release/repo > crontab.txt
"""

import sys
import os
from collections import defaultdict

try:
    import yaml
except ImportError:
    print("ERROR: PyYAML is required. Install with: pip install pyyaml", file=sys.stderr)
    sys.exit(1)

PERIODICS_RELPATH = (
    "ci-operator/jobs/openshift-eng/ocp-qe-perfscale-ci/"
    "openshift-eng-ocp-qe-perfscale-ci-main-periodics.yaml"
)

NAME_PREFIX = "periodic-ci-openshift-eng-ocp-qe-perfscale-ci-main-"


def extract_version(job):
    """Extract OCP version from the job-release label, falling back to name parsing."""
    labels = job.get("labels", {})
    if labels and "job-release" in labels:
        return labels["job-release"]

    variant = (labels or {}).get("ci-operator.openshift.io/variant", "")
    if variant:
        for part in variant.split("-"):
            if part and part[0].isdigit() and "." in part:
                return part

    name = job.get("name", "")
    stripped = name.replace(NAME_PREFIX, "")
    for part in stripped.split("-"):
        if part and part[0].isdigit() and "." in part:
            return part
    return "other"


def shorten_name(name):
    """Strip the common Prow job name prefix for readability."""
    if name.startswith(NAME_PREFIX):
        return name[len(NAME_PREFIX):]
    return name


def main():
    if len(sys.argv) < 2:
        print(f"Usage: {sys.argv[0]} <repo-root-path>", file=sys.stderr)
        sys.exit(1)

    repo_root = sys.argv[1]
    yaml_path = os.path.join(repo_root, PERIODICS_RELPATH)

    if not os.path.isfile(yaml_path):
        print(f"ERROR: Periodics file not found: {yaml_path}", file=sys.stderr)
        sys.exit(1)

    with open(yaml_path, "r") as f:
        data = yaml.safe_load(f)

    if not data or "periodics" not in data:
        print("ERROR: No 'periodics' key found in YAML", file=sys.stderr)
        sys.exit(1)

    jobs_by_version = defaultdict(list)

    for job in data["periodics"]:
        cron = job.get("cron")
        name = job.get("name", "")

        if not cron:
            continue

        version = extract_version(job)
        short_name = shorten_name(name)
        jobs_by_version[version].append((cron, short_name))

    if not jobs_by_version:
        print("WARNING: No cron jobs found in periodics file", file=sys.stderr)
        sys.exit(0)

    total = 0
    for version in sorted(jobs_by_version.keys(), key=version_sort_key, reverse=True):
        jobs = sorted(jobs_by_version[version], key=lambda j: j[1])
        label = f"OCP {version}" if version != "other" else "Other"
        print(f"\n# {label} Jobs")
        for cron_expr, job_name in jobs:
            print(f"{cron_expr} {job_name}")
            total += 1

    print(f"\nParsed {total} cron jobs", file=sys.stderr)


def version_sort_key(version):
    """Sort version strings numerically (e.g., '4.22' -> (4, 22), '5.0' -> (5, 0))."""
    try:
        parts = version.split(".")
        return tuple(int(p) for p in parts)
    except (ValueError, AttributeError):
        return (0, 0)


if __name__ == "__main__":
    main()
