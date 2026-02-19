import sys
sys.path.insert(0, 'src')
from dhcp_server import simulate_client

def main():
    simulate_client('127.0.0.1', 6767, print)

if __name__ == '__main__':
    main()
