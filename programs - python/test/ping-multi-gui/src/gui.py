from ttkbootstrap import Style
from ttkbootstrap.widgets import Entry, Button, Frame, Scrollbar
from tkinter import Tk, Label, Text, END, VERTICAL, RIGHT, Y, LEFT, BOTH
import threading
from ping import ping_ip

class MainWindow:
    def __init__(self, master):
        style = Style("cyborg")  # Try "superhero", "flatly", "morph", etc. for different looks
        master.configure(bg=style.colors.bg)

        self.label = Label(master, text="Enter IPs (comma separated):", bg=style.colors.bg, fg=style.colors.info, font=("Segoe UI", 12, "bold"))
        self.label.pack(pady=(10, 5))

        self.ip_entry = Entry(master, width=50, bootstyle="info", font=("Segoe UI", 11))
        self.ip_entry.pack(pady=5)

        self.start_button = Button(
            master, text="Start Ping", command=self.start_ping,
            bootstyle="success-outline", width=20
        )
        self.start_button.pack(pady=10)

        frame = Frame(master, bootstyle="secondary")
        frame.pack(pady=5, padx=10, fill=BOTH, expand=True)

        self.results_text = Text(frame, height=15, width=50, font=("Consolas", 10), bg="#232946", fg="#eebbc3", insertbackground="#eebbc3")
        self.results_text.pack(side=LEFT, fill=BOTH, expand=True)

        self.scrollbar = Scrollbar(frame, command=self.results_text.yview, orient=VERTICAL, bootstyle="round")
        self.results_text.config(yscrollcommand=self.scrollbar.set)
        self.scrollbar.pack(side=RIGHT, fill=Y)

    def start_ping(self):
        self.results_text.delete(1.0, END)
        ip_addresses = self.ip_entry.get().split(',')
        threads = []

        for ip in ip_addresses:
            ip = ip.strip()
            thread = threading.Thread(target=self.ping_ip, args=(ip,))
            threads.append(thread)
            thread.start()

    def ping_ip(self, ip):
        result = ping_ip(ip)
        self.results_text.insert(END, f"{ip}: {result}\n")