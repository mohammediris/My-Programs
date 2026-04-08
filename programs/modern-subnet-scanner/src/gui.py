import threading
from scanner import scan_subnet
import ttkbootstrap as tb
from ttkbootstrap.constants import *

class SubnetScannerGUI:
    def __init__(self, master):
        master.title("Modern Subnet Scanner")
        master.geometry("900x700")
        master.resizable(True, True)

        input_frame = tb.Frame(master, padding=20)
        input_frame.pack(fill=X, pady=(10, 0))
        tb.Label(input_frame, text="Enter Subnet (CIDR):", font=("Segoe UI", 12, "bold")).pack(anchor=W, pady=5)

        entry_button_frame = tb.Frame(input_frame)
        entry_button_frame.pack(anchor=W, pady=5, fill=X)
        self.subnet_entry = tb.Entry(entry_button_frame, width=35, font=("Segoe UI", 11))
        self.subnet_entry.pack(side=LEFT, padx=(0, 10))
        self.scan_button = tb.Button(entry_button_frame, text="Scan", bootstyle=PRIMARY, width=12, command=self.start_scan)
        self.scan_button.pack(side=LEFT)

        ports_frame = tb.Labelframe(master, text="Select Ports to Scan", padding=15, bootstyle=PRIMARY)
        ports_frame.pack(fill=X, padx=20, pady=10)

        self.well_known_ports = {
            "HTTP (80)": 80, "HTTPS (443)": 443, "SSH (22)": 22, "FTP (21)": 21,
            "Telnet (23)": 23, "SMTP (25)": 25, "DNS (53)": 53, "RDP (3389)": 3389
        }
        self.port_vars = {name: tb.BooleanVar(value=(name == "HTTP (80)")) for name in self.well_known_ports}
        self.select_all_var = tb.BooleanVar(value=False)

        def toggle_all_ports():
            for var in self.port_vars.values():
                var.set(self.select_all_var.get())
        tb.Checkbutton(
            ports_frame, text="All Ports", variable=self.select_all_var,
            command=toggle_all_ports, bootstyle=INFO
        ).grid(row=0, column=0, sticky='w', padx=10, pady=2, columnspan=2)

        for i, (name, var) in enumerate(self.port_vars.items()):
            tb.Checkbutton(ports_frame, text=name, variable=var, bootstyle=SUCCESS)\
                .grid(row=(i+1)//2, column=(i+1)%2, sticky='w', padx=10, pady=2)

        progress_frame = tb.Frame(master, padding=10)
        progress_frame.pack(fill=X, padx=20, pady=(0, 10))
        self.progress_bar = tb.Progressbar(progress_frame, orient=HORIZONTAL, length=700, mode="determinate", bootstyle=INFO)
        self.progress_bar.pack(fill=X, pady=5)
        self.progress_label = tb.Label(progress_frame, text="", font=("Segoe UI", 10))
        self.progress_label.pack(anchor=W)
        self.error_label = tb.Label(progress_frame, text="", font=("Segoe UI", 10), bootstyle="danger")
        self.error_label.pack(anchor=W, pady=(5, 0))

        output_frame = tb.Frame(master, padding=10)
        output_frame.pack(fill=BOTH, expand=True, padx=20, pady=(0, 10))
        self.output_text = tb.ScrolledText(output_frame, height=18, width=90, font=("Consolas", 10))
        self.output_text.pack(fill=BOTH, expand=True)

    def start_scan(self):
        subnet = self.subnet_entry.get()
        selected_ports = [self.well_known_ports[port] for port, var in self.port_vars.items() if var.get()]
        self.scan_button.config(state="disabled")
        self.output_text.delete("1.0", "end")
        self.progress_label.config(text="Starting scan...")
        self.error_label.config(text="")
        threading.Thread(target=self.run_scan, args=(subnet, selected_ports)).start()

    def run_scan(self, subnet, selected_ports):
        try:
            scan_subnet(subnet, selected_ports, self.output_text, self.progress_bar, self.progress_label, self.error_label)
        except Exception as e:
            self.error_label.config(text=f"Error: {e}")
        self.scan_button.config(state="normal")

def main():
    app = tb.Window(themename="superhero")
    SubnetScannerGUI(app)
    app.mainloop()

if __name__ == "__main__":
    main()