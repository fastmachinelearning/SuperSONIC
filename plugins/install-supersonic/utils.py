#!/usr/bin/env python3

import argparse
import sys
from typing import Dict, Any, List, Tuple

def deep_merge(base: Dict, custom: Dict) -> Dict:
    """
    Recursively merge two dictionaries.
    Custom values override base values at each level.
    """
    result = base.copy()
    for key, value in custom.items():
        if key in result and isinstance(result[key], dict) and isinstance(value, dict):
            result[key] = deep_merge(result[key], value)
        else:
            result[key] = value
    return result

class CustomHelpFormatter(argparse.HelpFormatter):
    """Custom formatter to match the previous help message style."""
    def format_help(self) -> str:
        help_text = []
        help_text.append("SuperSONIC Helm Plugin")
        help_text.append("")
        help_text.append("Usage:")
        help_text.append(f"  helm install-supersonic [RELEASE_NAME] [flags]")
        help_text.append("")
        help_text.append("Flags:")
        help_text.append("  -h, --help              Show help message")
        help_text.append("  -f, --values            Specify values file (optional, will use chart's default values if not provided)")
        help_text.append("  -n, --namespace         Specify Kubernetes namespace")
        help_text.append("  --local                 Install from local chart path (helm/supersonic)")
        help_text.append("  --version               Specify chart version (only for non-local installation)")
        help_text.append("")
        help_text.append("Additional flags will be passed directly to 'helm install' command")
        return "\n".join(help_text)

def process_remaining_args(args: argparse.Namespace, remaining: List[str]) -> List[str]:
    """Process remaining arguments to handle values file and return other helm args."""
    helm_args = []
    i = 0
    while i < len(remaining):
        if remaining[i] in ['-f', '--values']:
            if args.values_file is not None:
                print("Error: Multiple values files specified. Only one values file is allowed.")
                sys.exit(1)
            if i + 1 < len(remaining):
                args.values_file = remaining[i + 1]
                i += 2
                continue
        helm_args.append(remaining[i])
        i += 1
    return helm_args

def create_parser() -> argparse.ArgumentParser:
    """Create and configure argument parser."""
    parser = argparse.ArgumentParser(
        description="SuperSONIC Helm Plugin",
        formatter_class=CustomHelpFormatter,
        usage=argparse.SUPPRESS,  # Help is shown in custom format
    )
    parser.add_argument(
        'release_name',
        help=argparse.SUPPRESS  # Help is shown in custom format
    )
    parser.add_argument(
        '-f', '--values',
        dest='values_file',
        help=argparse.SUPPRESS,  # Help is shown in custom format
        default=None
    )
    parser.add_argument(
        '-n', '--namespace',
        help=argparse.SUPPRESS  # Help is shown in custom format
    )
    parser.add_argument(
        '--local',
        action='store_true',
        help=argparse.SUPPRESS,  # Help is shown in custom format
        default=False
    )
    parser.add_argument(
        '--version',
        help=argparse.SUPPRESS,  # Help is shown in custom format
        default=None
    )
    
    return parser

def parse_args() -> Tuple[argparse.Namespace, List[str]]:
    """Parse and process command line arguments."""
    parser = create_parser()
    args, remaining = parser.parse_known_args()
    args.helm_args = process_remaining_args(args, remaining)
    return args, remaining 