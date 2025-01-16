#!/usr/bin/env python3
import sys
import yaml
import json
from genson import SchemaBuilder

def main():
    input_file = sys.argv[1]
    output_file = sys.argv[2]

    with open(input_file, 'r') as f:
        data = yaml.safe_load(f)

    builder = SchemaBuilder()
    builder.add_object(data)
    schema = builder.to_schema()

    with open(output_file, 'w') as f:
        json.dump(schema, f, indent=2)

if __name__ == "__main__":
    main()