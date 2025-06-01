from tkinter import Tk
from gui import MainWindow

def main():
    root = Tk()
    root.title("Multi IP Pinger")
    app = MainWindow(root)
    root.mainloop()

if __name__ == "__main__":
    main()