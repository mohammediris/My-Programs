import subprocess
import socket
import requests
import re

def get_foreign_ips():
    result = subprocess.run(['netstat', '-n'], capture_output=True, text=True)
    lines = result.stdout.splitlines()
    foreign_ips = set()
    for line in lines:
        if line.startswith('  TCP'):
            parts = line.split()
            if len(parts) >= 3:
                foreign = parts[2]
                ip_port = foreign.rsplit(':', 1)[0]
                # Exclude local addresses
                if not (ip_port.startswith('127.') or ip_port.startswith('0.0.0.0') or ip_port.startswith('::1')):
                    foreign_ips.add(ip_port)
    return list(foreign_ips)

def get_fqdn(ip):
    try:
        return socket.getfqdn(ip)
    except Exception:
        return "N/A"

def get_location(ip):
    try:
        resp = requests.get(f"https://ipinfo.io/{ip}/json", timeout=3)
        if resp.status_code == 200:
            data = resp.json()
            return f"{data.get('city', '')}, {data.get('region', '')}, {data.get('country', '')}"
    except Exception:
        pass
    return "N/A"

def main():
    print(f"{'IP':<20} {'FQDN':<40} {'Location'}")
    print('-' * 80)
    for ip in get_foreign_ips():
        fqdn = get_fqdn(ip)
        location = get_location(ip)
        print(f"{ip:<20} {fqdn:<40} {location}")

if __name__ == "__main__":
    main()