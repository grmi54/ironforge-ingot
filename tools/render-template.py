#!/usr/bin/env python3
"""
IronForge Ingot - Template Renderer for Raspberry Pi
Renders cloud-init templates using profile YAML data with Jinja2.
"""

import sys
import yaml
from datetime import datetime
from jinja2 import Environment, FileSystemLoader, BaseLoader


def load_profile(profile_path):
    """Load and parse the YAML profile."""
    with open(profile_path, 'r') as f:
        data = yaml.safe_load(f)
    
    # Add default RPi values if missing
    if 'rpi' not in data:
        data['rpi'] = {}
    data['rpi'].setdefault('cpu_governor', 'performance')
    data['rpi'].setdefault('enable_zram', True)
    data['rpi'].setdefault('zram_fraction', 0.5)
    data['rpi'].setdefault('tmpfs_logs', True)
    data['rpi'].setdefault('wifi_enabled', True)
    data['rpi'].setdefault('bluetooth_enabled', True)
    
    # Add metadata
    data['timestamp'] = datetime.now().strftime('%Y%m%d%H%M%S')
    
    # Compute derived values
    if 'rpi' in data and 'zram_fraction' in data['rpi']:
        data['rpi']['zram_percent'] = int(data['rpi']['zram_fraction'] * 100)
    
    return data


def render_template(template_path, output_path, data):
    """Render template using Jinja2."""
    # Load template
    env = Environment(
        loader=FileSystemLoader('/'),
        trim_blocks=True,
        lstrip_blocks=True,
        keep_trailing_newline=True
    )
    
    template = env.get_template(template_path)
    rendered = template.render(**data)
    
    # Write output
    with open(output_path, 'w') as f:
        f.write(rendered)
    
    print(f"Rendered: {output_path}")


def render_user_data(template_path, profile_path, output_path, profile_name):
    """Render user-data template."""
    data = load_profile(profile_path)
    data['profile_name'] = profile_name
    
    render_template(template_path, output_path, data)


def render_meta_data(template_path, profile_path, output_path):
    """Render meta-data template."""
    data = load_profile(profile_path)
    
    render_template(template_path, output_path, data)


def main():
    if len(sys.argv) < 2:
        print("Usage: render-template.py <command> [options]")
        print("Commands:")
        print("  user-data <template> <profile> <output> <profile-name>")
        print("  meta-data <template> <profile> <output>")
        sys.exit(1)
    
    command = sys.argv[1]
    
    if command == 'user-data':
        if len(sys.argv) != 6:
            print("Usage: render-template.py user-data <template> <profile> <output> <profile-name>")
            sys.exit(1)
        render_user_data(sys.argv[2], sys.argv[3], sys.argv[4], sys.argv[5])
    
    elif command == 'meta-data':
        if len(sys.argv) != 5:
            print("Usage: render-template.py meta-data <template> <profile> <output>")
            sys.exit(1)
        render_meta_data(sys.argv[2], sys.argv[3], sys.argv[4])
    
    else:
        print(f"Unknown command: {command}")
        sys.exit(1)


if __name__ == '__main__':
    main()
