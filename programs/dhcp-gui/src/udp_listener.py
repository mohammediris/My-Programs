import socket
import sys

def main():
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    s.bind(("127.0.0.1", 6768))
    print("listening")
    sys.stdout.flush()
    data, addr = s.recvfrom(4096)
    print("got", data, addr)
    sys.stdout.flush()

if __name__ == '__main__':
    main()
