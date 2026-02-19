"""Minimal DHCP server implementation for demo purposes.

This server listens on a configurable UDP port (default 6767 to avoid privileged ports)
and responds to DHCPDISCOVER with DHCPOFFER and DHCPREQUEST with DHCPACK.
It maintains a tiny lease table and posts textual events to a provided logger callable.
"""
import socket
import os
import struct
import threading
import random
import ipaddress
import time
from queue import Queue

# DHCP constants
OP_BOOTREQUEST = 1
OP_BOOTREPLY = 2

DHCP_DISCOVER = 1
DHCP_OFFER = 2
DHCP_REQUEST = 3
DHCP_DECLINE = 4
DHCP_ACK = 5
DHCP_NAK = 6

MAGIC_COOKIE = b"\x63\x82\x53\x63"


def ip_to_bytes(ip_str):
    return socket.inet_aton(ip_str)


def bytes_to_ip(b):
    return socket.inet_ntoa(b)


def parse_options(options_data):
    opts = {}
    i = 0
    while i < len(options_data):
        opt = options_data[i]
        i += 1
        if opt == 255:  # end
            break
        if opt == 0:
            continue
        if i >= len(options_data):
            break
        length = options_data[i]
        i += 1
        if i + length > len(options_data):
            break
        data = options_data[i:i + length]
        i += length
        opts[opt] = data
    return opts


def build_options(opts_dict):
    parts = []
    for opt, data in opts_dict.items():
        parts.append(struct.pack("BB", opt, len(data)))
        parts.append(data)
    parts.append(b"\xff")
    return b"".join(parts)


class DHCPServer(threading.Thread):
    def __init__(self, bind_addr="0.0.0.0", port=6767, pool_start="192.168.50.100", pool_end="192.168.50.150", logger=None):
        super().__init__(daemon=True)
        self.bind_addr = bind_addr
        self.port = port
        self.logger = logger or (lambda s: print(s))
        self.pool_start = ipaddress.IPv4Address(pool_start)
        self.pool_end = ipaddress.IPv4Address(pool_end)
        self.leases = {}  # mac_str -> (ip_str, expiry)
        self.ip_map = {}  # ip_str -> mac_str
        self.running = threading.Event()
        self.sock = None

    def log(self, msg):
        ts = time.strftime("%H:%M:%S")
        self.logger(f"[{ts}] {msg}")

    def next_free_ip(self):
        cur = int(self.pool_start)
        end = int(self.pool_end)
        while cur <= end:
            ip = str(ipaddress.IPv4Address(cur))
            if ip not in self.ip_map:
                return ip
            cur += 1
        return None

    def run(self):
        self.running.set()
        self.sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        self.sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        # allow sending/receiving broadcasts
        try:
            self.sock.setsockopt(socket.SOL_SOCKET, socket.SO_BROADCAST, 1)
        except Exception:
            pass
        try:
            self.sock.bind((self.bind_addr, self.port))
        except OSError as e:
            self.log(f"Bind failed on {self.bind_addr}:{self.port}: {e}")
            self.running.clear()
            return
        self.log(f"Server listening on {self.bind_addr}:{self.port}")
        try:
            while self.running.is_set():
                try:
                    self.sock.settimeout(1.0)
                    data, addr = self.sock.recvfrom(2048)
                except socket.timeout:
                    continue
                except OSError:
                    break
                threading.Thread(target=self.handle_packet, args=(data, addr), daemon=True).start()
        finally:
            self.sock.close()
            self.log("Server stopped")

    def stop(self):
        self.running.clear()
        if self.sock:
            try:
                self.sock.close()
            except Exception:
                pass

    def handle_packet(self, data, addr):
        # Parse BOOTP fields minimally
        if len(data) < 240:
            self.log(f"Short packet ({len(data)} bytes) from {addr}")
            return
        op = data[0]
        xid = data[4:8]
        chaddr = data[28:28 + 16]
        mac = ":".join(f"{b:02x}" for b in chaddr[:6])
        # parse flags and giaddr
        flags = struct.unpack('!H', data[10:12])[0]
        broadcast_flag = bool(flags & 0x8000)
        giaddr_bytes = data[16:20]
        giaddr = None
        if giaddr_bytes != b"\x00\x00\x00\x00":
            giaddr = bytes_to_ip(giaddr_bytes)
        # options follow after 236 + 4 cookie
        cookie = data[236:240]
        if cookie != MAGIC_COOKIE:
            self.log(f"Bad magic cookie from {addr}: {cookie}")
            return
        options = parse_options(data[240:])
        msg_type = None
        if 53 in options:
            msg_type = options[53][0]

        self.log(f"Recv from {addr[0]}:{addr[1]} - MAC {mac} - msg_type {msg_type}")

        if msg_type == DHCP_DISCOVER:
            self.handle_discover(xid, mac, addr, broadcast_flag=broadcast_flag, giaddr=giaddr)
        elif msg_type == DHCP_REQUEST:
            self.handle_request(xid, mac, options, addr, broadcast_flag=broadcast_flag, giaddr=giaddr)

    def send_packet(self, pkt, target_addr):
        self.sock.sendto(pkt, target_addr)

    def make_reply(self, op, xid, yiaddr, chaddr, opts):
        # build minimal BOOTP/DHCP reply
        pkt = bytearray(240)
        pkt[0] = op
        pkt[1] = 1  # htype ethernet
        pkt[2] = 6  # hlen
        pkt[3] = 0  # hops
        pkt[4:8] = xid
        # secs and flags left zero
        # ciaddr (0-3), yiaddr (4-7), siaddr (8-11), giaddr (12-15)
        pkt[16:20] = b"\x00\x00\x00\x00"
        pkt[20:24] = ip_to_bytes(yiaddr)
        pkt[24:28] = b"\x00\x00\x00\x00"
        pkt[28:44] = chaddr.ljust(16, b"\x00")
        # sname and file left zero
        pkt[236:240] = MAGIC_COOKIE
        pkt.extend(build_options(opts))
        return bytes(pkt)

    def handle_discover(self, xid, mac, addr, broadcast_flag=False, giaddr=None):
        offered = self.next_free_ip()
        if not offered:
            self.log("No IPs left to offer")
            return
        self.log(f"Offering {offered} to {mac}")
        opts = {
            53: bytes([DHCP_OFFER]),
            54: ip_to_bytes(self.bind_addr),
            51: struct.pack("!I", 3600),
            1: ip_to_bytes("255.255.255.0"),
            3: ip_to_bytes(self.bind_addr),
            6: ip_to_bytes("8.8.8.8"),
        }
        # store a provisional mapping until request arrives
        self.ip_map[offered] = mac
        self.leases[mac] = (offered, time.time() + 3600)
        # chaddr needs to be 16 bytes; reconstruct from mac
        ch = bytes(int(x, 16) for x in mac.split(':'))
        pkt = self.make_reply(OP_BOOTREPLY, xid, offered, ch, opts)
        # choose destination: relay (giaddr) -> port 67, broadcast -> 255.255.255.255:68, else reply to source
        try:
            if giaddr:
                self.send_packet(pkt, (giaddr, 67))
            elif broadcast_flag:
                self.send_packet(pkt, ("255.255.255.255", 68))
            else:
                self.send_packet(pkt, addr)
        except Exception:
            try:
                self.send_packet(pkt, (addr[0], 68))
            except Exception:
                self.log("Failed to send OFFER")

    def handle_request(self, xid, mac, options, addr, broadcast_flag=False, giaddr=None):
        # requested IP is option 50 or ciaddr
        requested = None
        if 50 in options:
            requested = bytes_to_ip(options[50])
        else:
            requested = self.leases.get(mac, (None,))[0]
        if not requested:
            self.log(f"No requested IP from {mac}; sending NAK")
            return
        # grant the lease
        self.log(f"Granting {requested} to {mac}")
        self.ip_map[requested] = mac
        self.leases[mac] = (requested, time.time() + 3600)
        opts = {
            53: bytes([DHCP_ACK]),
            54: ip_to_bytes(self.bind_addr),
            51: struct.pack("!I", 3600),
            1: ip_to_bytes("255.255.255.0"),
            3: ip_to_bytes(self.bind_addr),
            6: ip_to_bytes("8.8.8.8"),
        }
        ch = bytes(int(x, 16) for x in mac.split(':'))
        pkt = self.make_reply(OP_BOOTREPLY, xid, requested, ch, opts)
        try:
            if giaddr:
                self.send_packet(pkt, (giaddr, 67))
            elif broadcast_flag:
                self.send_packet(pkt, ("255.255.255.255", 68))
            else:
                self.send_packet(pkt, addr)
        except Exception:
            try:
                self.send_packet(pkt, (addr[0], 68))
            except Exception:
                self.log("Failed to send ACK")


def simulate_client(server_addr="127.0.0.1", server_port=6767, logger=None):
    """Simple client simulator that performs DISCOVER -> REQUEST sequence.
    It logs messages via logger callable and helps visualize steps in the GUI.
    """
    logger = logger or (lambda s: print(s))
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    sock.setsockopt(socket.SOL_SOCKET, socket.SO_BROADCAST, 1)
    # bind source to loopback ephemeral port to stabilize Windows loopback behavior
    try:
        sock.bind(("127.0.0.1", 0))
    except Exception as e:
        logger(f"Client: bind failed: {e}")
    sock.settimeout(2.0)

    def build_discover(xid, mac_bytes):
        pkt = bytearray(240)
        pkt[0] = OP_BOOTREQUEST
        pkt[1] = 1
        pkt[2] = 6
        pkt[3] = 0
        pkt[4:8] = xid
        pkt[28:28 + len(mac_bytes)] = mac_bytes
        pkt[236:240] = MAGIC_COOKIE
        opts = {53: bytes([DHCP_DISCOVER])}
        pkt.extend(build_options(opts))
        return bytes(pkt)

    xid = struct.pack("!I", random.randint(0, 0xFFFFFFFF))
    mac = bytes(random.randint(0, 255) for _ in range(6))
    logger(f"Client: sending DISCOVER (xid={struct.unpack('!I', xid)[0]})")
    discover = build_discover(xid, mac)
    try:
        sock.sendto(discover, (server_addr, server_port))
    except Exception as e:
        logger(f"Client: send error: {e}")
        sock.close()
        return

    try:
        data, _ = sock.recvfrom(2048)
    except socket.timeout:
        logger("Client: no OFFER received (timeout)")
        sock.close()
        return
    except ConnectionResetError as e:
        logger(f"Client: connection reset: {e}")
        sock.close()
        return

    # parse offer
    if len(data) >= 240 and data[236:240] == MAGIC_COOKIE:
        opts = parse_options(data[240:])
        if 53 in opts and opts[53][0] == DHCP_OFFER:
            yiaddr = bytes_to_ip(data[20:24])
            logger(f"Client: received OFFER {yiaddr}")
            # send REQUEST for yiaddr
            req = bytearray(240)
            req[0] = OP_BOOTREQUEST
            req[4:8] = xid
            req[28:28 + len(mac)] = mac
            req[236:240] = MAGIC_COOKIE
            opts2 = {53: bytes([DHCP_REQUEST]), 50: ip_to_bytes(yiaddr)}
            req.extend(build_options(opts2))
            try:
                sock.sendto(bytes(req), (server_addr, server_port))
            except Exception as e:
                logger(f"Client: send REQUEST error: {e}")
                sock.close()
                return
            logger(f"Client: sent REQUEST for {yiaddr}")
            try:
                data2, _ = sock.recvfrom(2048)
            except socket.timeout:
                logger("Client: no ACK received (timeout)")
                sock.close()
                return
            except ConnectionResetError as e:
                logger(f"Client: connection reset waiting for ACK: {e}")
                sock.close()
                return
            if len(data2) >= 240 and data2[236:240] == MAGIC_COOKIE:
                opts3 = parse_options(data2[240:])
                if 53 in opts3 and opts3[53][0] == DHCP_ACK:
                    aiaddr = bytes_to_ip(data2[20:24])
                    logger(f"Client: received ACK {aiaddr}")
    sock.close()


def get_interfaces():
    """Return a dict of interface name -> list of IPv4 addresses.
    Tries to use psutil if available, otherwise falls back to a minimal loopback-only result.
    """
    try:
        import psutil
    except Exception:
        return {"lo": ["127.0.0.1"]}

    result = {}
    addrs = psutil.net_if_addrs()
    for ifname, addrlist in addrs.items():
        ips = []
        for a in addrlist:
            # psutil.AddressFamily.AF_INET == socket.AF_INET
            try:
                if a.family.name == 'AF_INET':
                    ips.append(a.address)
            except Exception:
                # fallback: compare integer
                import socket
                if getattr(a, 'family', None) == socket.AF_INET:
                    ips.append(a.address)
        if ips:
            result[ifname] = ips
    return result


def is_admin():
    """Return True if the process has administrator/root privileges."""
    try:
        if os.name == 'nt':
            import ctypes
            return ctypes.windll.shell32.IsUserAnAdmin() != 0
        else:
            return os.geteuid() == 0
    except Exception:
        return False
