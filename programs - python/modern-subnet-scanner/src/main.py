import tkinter as tk
from gui import create_gui

def main():
    root = tk.Tk()
    create_gui(root)
    root.mainloop()

if __name__ == "__main__":
    main()