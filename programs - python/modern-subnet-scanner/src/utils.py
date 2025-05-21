def validate_cidr(cidr):
    try:
        ipaddress.ip_network(cidr, strict=False)
        return True
    except ValueError:
        return False

def format_scan_result(ip, open_ports):
    return f"{ip} [Ports: {', '.join(map(str, open_ports))}]" if open_ports else f"{ip} [No open ports]"