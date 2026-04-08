import sys
import time
import serial
import serial.tools.list_ports

def is_valid_port(port):
    hwid = (port.hwid or "").upper()
    desc = (port.description or "").upper()
    # hide these Bluetooth / virtual keys
    if "BTHENUM" in hwid or "BTHENUM" in desc:
        return False
    return True

def list_com_ports():
    ports = [p for p in serial.tools.list_ports.comports() if is_valid_port(p)]
    if not ports:
        print("No valid COM ports found.")
        return []
    print("Available COM ports:")
    for p in ports:
        print(f" - {p.device}  • {p.description or 'no description'}")
    return ports

def find_usb_serial_port():
    ports = list_com_ports()
    if not ports:
        return None
    for p in ports:
        if "USB" in (p.description or "").upper() or "USB" in (p.manufacturer or "").upper():
            return p.device
    return ports[0].device

def keyboard_input_available():
    if sys.platform.startswith("win"):
        import msvcrt
        return msvcrt.kbhit()
    else:
        import select
        return sys.stdin in select.select([sys.stdin], [], [], 0)[0]

def read_keyboard_char():
    if sys.platform.startswith("win"):
        import msvcrt
        ch = msvcrt.getwch()
        return "\n" if ch == "\r" else ch
    else:
        return sys.stdin.read(1)

def main():
    port = find_usb_serial_port()
    if not port:
        print("No COM port detected. Plug in cable and try again.")
        sys.exit(1)

    print(f"Using serial port: {port} (9600 baud)")
    try:
        with serial.Serial(port, baudrate=9600, timeout=0.2) as ser:
            print("Connected. Ctrl-C to exit.")
            while True:
                if ser.in_waiting:
                    data = ser.read(ser.in_waiting)
                    sys.stdout.write(data.decode(errors="replace"))
                    sys.stdout.flush()

                if keyboard_input_available():
                    user_input = read_keyboard_char()
                    if user_input:
                        ser.write(user_input.encode("utf-8", errors="replace"))

                time.sleep(0.01)

    except serial.SerialException as e:
        print("Serial error:", e)
        sys.exit(2)
    except KeyboardInterrupt:
        print("\nExited cleanly.")

if __name__ == "__main__":
    main()