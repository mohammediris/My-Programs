import socket

def main():
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    s.sendto(b'hello', ("127.0.0.1", 6768))

if __name__ == '__main__':
    main()
