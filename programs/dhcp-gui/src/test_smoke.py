import sys
import time

sys.path.insert(0, 'src')
from dhcp_server import DHCPServer, simulate_client
import socket


def main():
    server = DHCPServer(bind_addr='0.0.0.0', port=6767, logger=print)
    server.start()
    time.sleep(1.0)
    # quick raw UDP test
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    s.sendto(b'hello', ('127.0.0.1', 6767))
    s.close()
    time.sleep(0.2)
    simulate_client('127.0.0.1', 6767, print)
    time.sleep(1.0)
    server.stop()
    time.sleep(0.2)


if __name__ == '__main__':
    main()
