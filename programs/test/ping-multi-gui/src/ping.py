import subprocess
import platform
import concurrent.futures

def ping_ip(ip):
    # Use '-n' for Windows, '-c' for Unix
    param = '-n' if platform.system().lower() == 'windows' else '-c'
    command = ['ping', param, '1', ip]
    try:
        output = subprocess.check_output(command, stderr=subprocess.STDOUT, universal_newlines=True, timeout=2)
        if "unreachable" in output.lower() or "timed out" in output.lower():
            return "No response"
        return "Alive"
    except subprocess.CalledProcessError:
        return "No response"
    except Exception as e:
        return f"Error: {e}"

def ping_ips(ip_addresses):
    results = {}
    with concurrent.futures.ThreadPoolExecutor() as executor:
        future_to_ip = {executor.submit(ping_ip, ip): ip for ip in ip_addresses}
        for future in concurrent.futures.as_completed(future_to_ip):
            ip = future_to_ip[future]
            try:
                results[ip] = future.result()
            except Exception as e:
                results[ip] = f"Error: {e}"
    
    return results