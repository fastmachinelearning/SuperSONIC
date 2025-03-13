#!/usr/bin/env python3

import argparse
import sys
import logging
from typing import Dict, Any, List, Tuple

def setup_logging(log_level=logging.INFO) -> logging.Logger:
    """
    Set up and configure logging for the installer plugin.
    
    Args:
        log_level: The logging level to use (default: logging.INFO)
        
    Returns:
        The configured logger.
    """
    # Get or create the logger
    logger = logging.getLogger("supersonic-installer")
    
    # Clear any existing handlers to avoid duplicate messages
    # if the function is called multiple times
    if logger.handlers:
        logger.handlers.clear()
    
    logger.setLevel(log_level)
    
    # Create console handler with a specific format to match the previous print output
    console_handler = logging.StreamHandler(sys.stdout)
    console_handler.setLevel(log_level)
    
    # Create a formatter that doesn't include the logger name or timestamp
    formatter = logging.Formatter('%(message)s')
    console_handler.setFormatter(formatter)
    
    # Add the handler to the logger
    logger.addHandler(console_handler)
    
    # Prevent propagation to the root logger to avoid duplicate messages
    logger.propagate = False
    
    return logger

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
        help_text.append("======================")
        help_text.append("")
        help_text.append("This plugin simplifies the SuperSONIC installation process by")
        help_text.append("handling chart dependencies and generating appropriate configurations.")
        help_text.append("")
        help_text.append("Usage:")
        help_text.append("  helm install-supersonic [RELEASE_NAME] [flags]")
        help_text.append("")
        help_text.append("Flags:")
        help_text.append("  -h, --help              Show this help message")
        help_text.append("  -f, --values            Specify values file for custom configuration")
        help_text.append("  -n, --namespace         Specify Kubernetes namespace for deployment")
        help_text.append("  --version               Specify chart version (default: latest version)")
        help_text.append("                          Note: Ignored if --local flag is set")
        help_text.append("  --local                 Install from local chart path instead of remote repository")
        help_text.append("  --path                  Local chart path (default: ./helm/supersonic)")
        help_text.append("                          Only used when --local flag is set")
        help_text.append("Additional flags will be passed directly to the 'helm install' command")
        help_text.append("")
        help_text.append("Examples:")
        help_text.append("  # Install SuperSONIC from official repository")
        help_text.append("  helm install-supersonic my-release -f my-values.yaml -n my-namespace")
        help_text.append("")
        help_text.append("  # Install SuperSONIC from local chart")
        help_text.append("  helm install-supersonic my-release -f my-values.yaml -n my-namespace --local --path <repo_path>/helm/supersonic")
        help_text.append("")
        return "\n".join(help_text)

def process_remaining_args(args: argparse.Namespace, remaining: List[str]) -> List[str]:
    """Process remaining arguments to handle values file and return other helm args."""
    logger = logging.getLogger("supersonic-installer")
    helm_args = []
    i = 0
    while i < len(remaining):
        if remaining[i] in ['-f', '--values']:
            if args.values_file is not None:
                logger.error("Error: Multiple values files specified. Only one values file is allowed.")
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
        '--path',
        help=argparse.SUPPRESS,  # Help is shown in custom format
        default="helm/supersonic"
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