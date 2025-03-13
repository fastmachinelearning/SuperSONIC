#!/usr/bin/env python3

import os
import sys
import yaml
import subprocess
import tempfile
import logging
from typing import Optional, Dict
from utils import (
    deep_merge,
    parse_args,
    setup_logging
)
from overrides import (
    generate_overrides
)

REPO_CHART = "fastml/supersonic"
REPO_URL = "https://fastmachinelearning.org/SuperSONIC"

def process_values(values_file: Optional[str], chart_path: str, release_name: str, use_local: bool, version: Optional[str] = None) -> Dict:
    """Process and merge values files."""
    logger = logging.getLogger("supersonic-installer")
    logger.info("╔══════════════════════════════════════════════════════════════════════")
    logger.info("║ Running Helm plugin 'install-supersonic' ")
    logger.info("╠══════════════════════════════════════════════════════════════════════")

    # Get default values
    if use_local:
        if not os.path.isdir(chart_path):
            logger.error(f"Error: SuperSONIC chart not found at {chart_path}")
            sys.exit(1)

        default_values_path = os.path.join(chart_path, "values.yaml")
        if not os.path.isfile(default_values_path):
            logger.error("Error: Default values file not found in chart")
            sys.exit(1)
        logger.info(f"║ Default values: {default_values_path} ")
        with open(default_values_path, 'r') as f:
            result = yaml.safe_load(f) or {}
    else:
        # Add repository and fetch default values from remote
        subprocess.run(["helm", "repo", "add", "fastml", REPO_URL], check=True)
        subprocess.run(["helm", "repo", "update"], check=True)
        
        cmd = ["helm", "show", "values", REPO_CHART]
        if version:
            cmd.extend(["--version", version])
        
        logger.info("║ Fetching default values from remote repository")
        try:
            values_output = subprocess.check_output(cmd, text=True)
            result = yaml.safe_load(values_output) or {}
        except subprocess.CalledProcessError as e:
            logger.error(f"Error: Failed to fetch default values from repository: {e}")
            sys.exit(1)

    # Load custom values
    if values_file:
        if not os.path.isfile(values_file):
            logger.error(f"Error: values file '{values_file}' not found")
            sys.exit(1)
        logger.info(f"║ Custom values: {values_file} ")
        with open(values_file, 'r') as f:
            # Merge custom values with default values
            result = deep_merge(result, yaml.safe_load(f) or {})

    # Generate overrides
    overrides = generate_overrides(release_name, result)
    logger.info("║ Generated overrides for config sections:")
    for key in overrides:
        logger.info(f"║   • {key}")

    # Merge overrides with result
    result = deep_merge(result, overrides)
    return result

def main() -> None:
    """Main entry point."""
    # Setup logging
    logger = setup_logging()
    
    args, _ = parse_args()

    # Process values: merge default values with custom values, then generate overrides
    # and merge them onto the result
    merged_values = process_values(args.values_file, args.path, args.release_name, args.local, args.version)
    
    # Write generated values to a temporary file
    with tempfile.NamedTemporaryFile(mode='w', suffix='.yaml', delete=False) as tmp:
        yaml.dump(merged_values, tmp, default_flow_style=False)
        tmp_values_file = tmp.name
        logger.info(f"║ Writing merged values to temporary file: {tmp_values_file} ")
        logger.info("╚══════════════════════════════════════════════════════════════════════")

    try:
        # Construct and execute helm command
        chart_source = args.path if args.local else REPO_CHART

        # Add dependencies
        repo_commands = []
        if merged_values.get("prometheus", {}).get("enabled", False):
            repo_commands.append(["helm", "repo", "add", "prometheus-community", "https://prometheus-community.github.io/helm-charts"])
        if merged_values.get("grafana", {}).get("enabled", False):
            repo_commands.append(["helm", "repo", "add", "grafana", "https://grafana.github.io/helm-charts"])
        if merged_values.get("opentelemetry-collector", {}).get("enabled", False):
            repo_commands.append(["helm", "repo", "add", "opentelemetry", "https://open-telemetry.github.io/opentelemetry-helm-charts"])
        if args.local:
            repo_commands.append(["helm", "dependency", "build", chart_source])

        for cmd in repo_commands:
            logger.info(f"\nExecuting: {' '.join(cmd)}")
            subprocess.run(cmd, check=True)
            
        cmd = ["helm", "install", args.release_name, chart_source, "-f", tmp_values_file]
        if args.namespace:
            cmd.extend(["-n", args.namespace])
        if args.helm_args:
            cmd.extend(args.helm_args)
        if not args.local and args.version:
            cmd.extend(["--version", args.version])
            
        logger.info(f"\nExecuting: {' '.join(cmd)}\n")
        result = subprocess.run(cmd)
        if result.returncode != 0:
            sys.exit(result.returncode)
            
    finally:
        # Clean up temporary file
        logger.info(f"\n=== Cleaning up temporary valuesfile: {tmp_values_file} ===")
        os.unlink(tmp_values_file)

if __name__ == "__main__":
    main() 