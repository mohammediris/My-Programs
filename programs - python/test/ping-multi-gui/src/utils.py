def validate_ip(ip):
    import re
    pattern = r"^(?:[0-9]{1,3}\.){3}[0-9]{1,3}$"
    if re.match(pattern, ip):
        return all(0 <= int(part) < 256 for part in ip.split('.'))
    return False

def validate_ip_list(ip_list):
    return all(validate_ip(ip) for ip in ip_list)