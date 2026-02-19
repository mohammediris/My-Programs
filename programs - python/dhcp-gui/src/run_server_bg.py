import sys, time
sys.path.insert(0, 'src')
from dhcp_server import DHCPServer

def main():
    s = DHCPServer(bind_addr='0.0.0.0', port=6767, logger=print)
    s.start()
    try:
        time.sleep(30)
    except KeyboardInterrupt:
        pass
    s.stop()

if __name__ == '__main__':
    main()
