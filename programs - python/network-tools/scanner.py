
import socket
import ipaddress

def scan_subnet(subnet, ports):
    results = []
    try:
        net = ipaddress.ip_network(subnet, strict=False)
    except Exception as e:
        return f"Invalid subnet: {e}"
    for ip in net.hosts():
        ip_str = str(ip)
        open_ports = []
        for port in ports:
            try:
                sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
                sock.settimeout(0.5)
                result = sock.connect_ex((ip_str, port))
                if result == 0:
                    open_ports.append(port)
                sock.close()
            except Exception:
                continue
        if open_ports:
            results.append(f"{ip_str}: Open ports: {', '.join(map(str, open_ports))}")
    return results if results else ["No open ports found."]