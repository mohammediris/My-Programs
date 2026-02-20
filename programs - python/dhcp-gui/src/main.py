import tkinter as tk
from gui import DHCPGui


def main():
    # prefer ttkbootstrap for a modern look if available
    try:
        import ttkbootstrap as tb
        root = tb.Window(themename='darkly')
    except Exception:
        root = tk.Tk()
    
    root.title("DHCP Server Demo")
    root.state('zoomed')  # Maximize window on Windows
    app = DHCPGui(root)
    root.mainloop()


if __name__ == '__main__':
    main()
