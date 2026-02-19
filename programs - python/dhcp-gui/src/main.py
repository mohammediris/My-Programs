import tkinter as tk
from gui import DHCPGui


def main():
    # prefer ttkbootstrap for a modern look if available
    try:
        import ttkbootstrap as tb
        root = tb.Window(themename='darkly')
        root.geometry('1100x700')
    except Exception:
        root = tk.Tk()
        root.geometry('1100x700')
    
    root.title("DHCP Server Demo")
    app = DHCPGui(root)
    root.mainloop()


if __name__ == '__main__':
    main()
