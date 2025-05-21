import tkinter as tk
from tkinter import scrolledtext
from concurrent.futures import ThreadPoolExecutor
import platform
import subprocess

# Ping command generator based on OS
def ping(host):
    param = "-n" if platform.system().lower() == "windows" else "-c"
    command = ["ping", param, "1", host]
    try:
        output = subprocess.check_output(command, stderr=subprocess.DEVNULL, universal_newlines=True)
        return f"{host}: ✅ Reachable"
    except subprocess.CalledProcessError:
        return f"{host}: ❌ Unreachable"

# Function to execute pings in parallel
def run_ping_checks():
    result_box.delete("1.0", tk.END)
    hosts = input_box.get("1.0", tk.END).strip().splitlines()
    if not hosts:
        result_box.insert(tk.END, "No input provided.\n")
        return

    with ThreadPoolExecutor(max_workers=10) as executor:
        futures = {executor.submit(ping, host): host for host in hosts}
        for future in futures:
            result = future.result()
            result_box.insert(tk.END, result + "\n")

# GUI setup
root = tk.Tk()
root.title("Ping Tester - Parallel Network Reachability Tool")
root.geometry("600x500")

tk.Label(root, text="Enter Hostnames/IPs (one per line):").pack(pady=5)

input_box = scrolledtext.ScrolledText(root, height=10, width=70)
input_box.pack(pady=5)

tk.Button(root, text="Check Connectivity", command=run_ping_checks, bg="green", fg="white").pack(pady=10)

tk.Label(root, text="Results:").pack()

result_box = scrolledtext.ScrolledText(root, height=15, width=70)
result_box.pack(pady=5)

root.mainloop()
