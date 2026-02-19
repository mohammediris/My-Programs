import tkinter as tk
from gui import DHCPGui


def main():
    # prefer ttkbootstrap for a modern look if available
    try:
        import ttkbootstrap as tb
        root = tb.Window(themename='flatly')
    except Exception:
        root = tk.Tk()
    app = DHCPGui(root)
    root.mainloop()


if __name__ == '__main__':
    main()
