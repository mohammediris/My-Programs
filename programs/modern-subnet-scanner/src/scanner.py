import socket
import ipaddress
import threading
from queue import Queue
import time

WELL_KNOWN_PORTS = {
    "HTTP (80)": 80,
    "HTTPS (443)": 443,
    "SSH (22)": 22,
    "FTP (21)": 21,
    "Telnet (23)": 23,
    "SMTP (25)": 25,
    "DNS (53)": 53,
    "RDP (3389)": 3389
}

def scan_host(ip, ports, result_queue):
    open_ports = []
    for port in ports:
        try:
            with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as sock:
                sock.settimeout(0.5)
                if sock.connect_ex((str(ip), port)) == 0:
                    open_ports.append(port)
        except Exception:
            pass
    if open_ports:
        try:
            fqdn = socket.getfqdn(str(ip))
        except Exception:
            fqdn = "N/A"
        result_queue.put(f"{ip} ({fqdn}) [Ports: {', '.join(map(str, open_ports))}]")

def scan_subnet(subnet, ports, output_text, progress_bar, progress_label, error_label=None):
    try:
        ip_net = ipaddress.ip_network(subnet, strict=False)
    except ValueError as ve:
        if error_label:
            error_label.config(text=f"Invalid subnet: {ve}")
        else:
            output_text.insert("end", f"Invalid subnet: {ve}\n")
        progress_label.config(text="Invalid subnet.")
        return
    except Exception as e:
        if error_label:
            error_label.config(text=f"Error: {e}")
        else:
            output_text.insert("end", f"Error: {e}\n")
        progress_label.config(text="Error occurred.")
        return

    all_ips = list(ip_net.hosts())
    total_hosts = len(all_ips)
    progress_bar["maximum"] = total_hosts
    progress_bar["value"] = 0
    progress_label.config(text="Scanning...")

    result_queue = Queue()
    threads = []

    def thread_target(ip):
        scan_host(ip, ports, result_queue)
        progress_queue.put(1)

    progress_queue = Queue()
    for ip in all_ips:
        t = threading.Thread(target=thread_target, args=(ip,))
        threads.append(t)
        t.start()

    scanned = 0
    while scanned < total_hosts:
        progress_queue.get()
        scanned += 1
        progress_bar["value"] = scanned
        progress_label.config(text=f"Scanned {scanned}/{total_hosts} hosts")
        # Allow GUI to update
        output_text.update_idletasks()
        progress_bar.update_idletasks()
        progress_label.update_idletasks()

    for t in threads:
        t.join()

    while not result_queue.empty():
        result = result_queue.get()
        output_text.insert("end", f"Host Up: {result}\n")
        output_text.update_idletasks()

    progress_label.config(text="Scan complete.")