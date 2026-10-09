#!/usr/bin/env python3
import sys
import yaml
import json
from genson import SchemaBuilder


def drop_required(node):
    """Drop genson's "required" lists: they mirror the defaults, so they only
    reject a values file that nulls a default key (e.g. `command: null`)."""
    if isinstance(node, dict):
        if isinstance(node.get("required"), list):  # not a property named "required"
            del node["required"]
        for value in node.values():
            drop_required(value)
    elif isinstance(node, list):
        for value in node:
            drop_required(value)


def main():
    input_file = sys.argv[1]
    output_file = sys.argv[2]

    with open(input_file, 'r') as f:
        data = yaml.safe_load(f)

    builder = SchemaBuilder()
    builder.add_object(data)
    schema = builder.to_schema()
    drop_required(schema)

    with open(output_file, 'w') as f:
        json.dump(schema, f, indent=2)

if __name__ == "__main__":
    main()