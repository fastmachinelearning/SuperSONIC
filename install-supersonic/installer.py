#!/usr/bin/env python3

import os
import sys
import yaml
import subprocess
import tempfile
from typing import Optional, Dict
from utils import (
    deep_merge,
    parse_args
)
from overrides import (
    generate_overrides
)

REPO_CHART = "fastml/supersonic"

def process_values(values_file: Optional[str], chart_path: str, release_name: str, use_local: bool, version: Optional[str] = None) -> Dict:
    """Process and merge values files."""
    print("╔══════════════════════════════════════════════════════════════════════")
    print("║ Running Helm plugin 'install-supersonic' ")
    print("╠══════════════════════════════════════════════════════════════════════")

    # Get default values
    if use_local:
        if not os.path.isdir(chart_path):
            print(f"Error: SuperSONIC chart not found at {chart_path}")
            sys.exit(1)

        default_values_path = os.path.join(chart_path, "values.yaml")
        if not os.path.isfile(default_values_path):
            print("Error: Default values file not found in chart")
            sys.exit(1)
        print(f"║ Default values: {default_values_path} ")
        with open(default_values_path, 'r') as f:
            result = yaml.safe_load(f) or {}
    else:
        # Add repository and fetch default values from remote
        subprocess.run(["helm", "repo", "add", "fastml", "https://fastmachinelearning.org/SuperSONIC"], check=True)
        subprocess.run(["helm", "repo", "update"], check=True)
        
        cmd = ["helm", "show", "values", REPO_CHART]
        if version:
            cmd.extend(["--version", version])
        
        print("║ Fetching default values from remote repository")
        try:
            values_output = subprocess.check_output(cmd, text=True)
            result = yaml.safe_load(values_output) or {}
        except subprocess.CalledProcessError as e:
            print(f"Error: Failed to fetch default values from repository: {e}")
            sys.exit(1)

    # Load custom values
    if values_file:
        if not os.path.isfile(values_file):
            print(f"Error: values file '{values_file}' not found")
            sys.exit(1)
        print(f"║ Custom values: {values_file} ")
        with open(values_file, 'r') as f:
            # Merge custom values with default values
            result = deep_merge(result, yaml.safe_load(f) or {})

    # Generate overrides
    overrides = generate_overrides(release_name, result)
    print("║ Generated overrides for config sections:")
    for key in overrides:
        print(f"║   • {key}")

    # Merge overrides with result
    result = deep_merge(result, overrides)
    return result

def main() -> None:
    """Main entry point."""
    args, _ = parse_args()

    # Process values: merge default values with custom values, then generate overrides
    # and merge them onto the result
    merged_values = process_values(args.values_file, args.path, args.release_name, args.local, args.version)
    
    # Write generated values to a temporary file
    with tempfile.NamedTemporaryFile(mode='w', suffix='.yaml', delete=False) as tmp:
        yaml.dump(merged_values, tmp, default_flow_style=False)
        tmp_values_file = tmp.name
        print(f"║ Writing merged values to temporary file: {tmp_values_file} ")
        print("╚══════════════════════════════════════════════════════════════════════")

    try:
        # Construct and execute helm command
        chart_source = args.path if args.local else REPO_CHART

        # Add dependencies
        repo_commands = [
            ["helm", "repo", "add", "prometheus-community", "https://prometheus-community.github.io/helm-charts"],
            ["helm", "repo", "add", "grafana", "https://grafana.github.io/helm-charts"],
            ["helm", "repo", "add", "opentelemetry", "https://open-telemetry.github.io/opentelemetry-helm-charts"],
            ["helm", "dependency", "build", chart_source]
        ]
        for cmd in repo_commands:
            print(f"\nExecuting: {' '.join(cmd)}")
            subprocess.run(cmd, check=True)
            
        cmd = ["helm", "install", args.release_name, chart_source, "-f", tmp_values_file]
        if args.namespace:
            cmd.extend(["-n", args.namespace])
        if args.helm_args:
            cmd.extend(args.helm_args)
        if not args.local and args.version:
            cmd.extend(["--version", args.version])
            
        print(f"\nExecuting: {' '.join(cmd)}\n")
        result = subprocess.run(cmd)
        if result.returncode != 0:
            sys.exit(result.returncode)
            
    finally:
        # Clean up temporary file
        print(f"\n=== Cleaning up temporary valuesfile: {tmp_values_file} ===")
        os.unlink(tmp_values_file)

if __name__ == "__main__":
    main() 