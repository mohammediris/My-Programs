import threading
import queue
import sys
import os
import subprocess
import tkinter as tk
try:
    import ttkbootstrap as tb
    from ttkbootstrap import ttk, Style
    from tkinter import messagebox
    USING_TTB = True
except Exception:
    from tkinter import ttk, messagebox
    USING_TTB = False
from dhcp_server import DHCPServer, simulate_client, get_interfaces, is_admin


class DHCPGui:
    def __init__(self, root):
        self.root = root
        root.title("DHCP Server Demo")
        self.log_q = queue.Queue()

        frm = ttk.Frame(root, padding=10)
        frm.grid(sticky="nsew")

        left = ttk.Frame(frm)
        left.grid(row=0, column=0, sticky="ns", padx=(0, 10))

        # Interface selector
        ttk.Label(left, text="Interface:").grid(row=0, column=0, sticky="w")
        self.iface_cb = ttk.Combobox(left, state='readonly')
        self.iface_cb.grid(row=1, column=0, sticky="we")
        self.iface_cb.bind('<<ComboboxSelected>>', self._on_iface_selected)

        # Bind address
        ttk.Label(left, text="Bind Address:").grid(row=2, column=0, sticky="w")
        self.bind_entry = ttk.Entry(left)
        self.bind_entry.insert(0, "127.0.0.1")
        self.bind_entry.grid(row=3, column=0, sticky="we")

        # Port and privileged option
        ttk.Label(left, text="Port:").grid(row=4, column=0, sticky="w")
        self.port_entry = ttk.Entry(left)
        self.port_entry.insert(0, "6767")
        self.port_entry.grid(row=5, column=0, sticky="we")

        self.use_priv_var = tk.BooleanVar(value=False)
        self.priv_cb = ttk.Checkbutton(left, text='Use port 67 (requires admin)', variable=self.use_priv_var, command=self._on_priv_toggle)
        self.priv_cb.grid(row=6, column=0, sticky='we', pady=(4,0))

        # Pool range
        ttk.Label(left, text="Pool Start:").grid(row=7, column=0, sticky="w")
        self.pool_start = ttk.Entry(left)
        self.pool_start.insert(0, "192.168.50.100")
        self.pool_start.grid(row=8, column=0, sticky="we")

        ttk.Label(left, text="Pool End:").grid(row=9, column=0, sticky="w")
        self.pool_end = ttk.Entry(left)
        self.pool_end.insert(0, "192.168.50.150")
        self.pool_end.grid(row=10, column=0, sticky="we")

        self.start_btn = ttk.Button(left, text="Start Server", command=self.toggle_server)
        self.start_btn.grid(row=11, column=0, pady=(8, 0), sticky="we")

        self.sim_btn = ttk.Button(left, text="Simulate Client", command=self.simulate)
        self.sim_btn.grid(row=12, column=0, pady=(6, 0), sticky="we")

        self.relaunch_btn = ttk.Button(left, text="Relaunch as Admin", command=self.relaunch_as_admin)
        self.relaunch_btn.grid(row=14, column=0, pady=(6, 0), sticky="we")

        right = ttk.Frame(frm)
        right.grid(row=0, column=1, sticky="nsew")
        frm.columnconfigure(1, weight=1)
        frm.rowconfigure(0, weight=1)

        self.log = tk.Text(right, width=80, height=24)
        self.log.grid(row=0, column=0, sticky="nsew")

        self.server = None

        # populate interfaces
        self.if_map = get_interfaces()
        items = []
        for name, ips in self.if_map.items():
            items.append(f"{name} ({', '.join(ips)})")
        if not items:
            items = ["lo (127.0.0.1)"]
            self.if_map = {"lo": ["127.0.0.1"]}
        self.iface_cb['values'] = items
        try:
            self.iface_cb.current(0)
        except Exception:
            pass
        # set bind address to first interface ip
        first_ip = list(self.if_map.values())[0][0]
        self.bind_entry.delete(0, 'end')
        self.bind_entry.insert(0, first_ip)

        self.if_warn = ttk.Label(left, text='', foreground='orange')
        self.if_warn.grid(row=13, column=0, sticky='we')

        self.root.after(200, self._poll_log)

    def _poll_log(self):
        while True:
            try:
                msg = self.log_q.get_nowait()
            except queue.Empty:
                break
            else:
                self.log.insert("end", msg + "\n")
                self.log.see("end")
        self.root.after(200, self._poll_log)

    def logger(self, msg):
        self.log_q.put(msg)

    def toggle_server(self):
        if self.server and self.server.running.is_set():
            self.server.stop()
            self.start_btn.config(text="Start Server")
            self.logger("Stopping server...")
        else:
            bind = self.bind_entry.get().strip() or "127.0.0.1"
            # if user asked for privileged port, force 67 but require admin
            if self.use_priv_var.get():
                if not is_admin():
                    self.logger('Cannot use port 67 without Administrator privileges.')
                    self.if_warn.config(text='Not Administrator — cannot bind port 67')
                    return
                port = 67
                self.port_entry.delete(0, 'end')
                self.port_entry.insert(0, '67')
                self.if_warn.config(text='Using port 67 (Administrator)')
            else:
                port = int(self.port_entry.get().strip() or 6767)
            pool_start = self.pool_start.get().strip() or "192.168.50.100"
            pool_end = self.pool_end.get().strip() or "192.168.50.150"
            # validate bind is in pool range
            try:
                import ipaddress
                ip_val = ipaddress.IPv4Address(bind)
                start = ipaddress.IPv4Address(pool_start)
                end = ipaddress.IPv4Address(pool_end)
                if int(ip_val) < int(start) or int(ip_val) > int(end):
                    self.if_warn.config(text='Warning: interface IP not in pool range')
                else:
                    self.if_warn.config(text='')
            except Exception:
                self.if_warn.config(text='')
            self.server = DHCPServer(bind_addr=bind, port=port, pool_start=pool_start, pool_end=pool_end, logger=self.logger)
            self.server.start()
            self.start_btn.config(text="Stop Server")
            self.logger("Server started")

    def simulate(self):
        if not self.server:
            self.logger("Start the server first")
            return
        t = threading.Thread(target=simulate_client, args=(self.bind_entry.get().strip() or "127.0.0.1", int(self.port_entry.get().strip() or 6767), self.logger), daemon=True)
        t.start()

    def _on_iface_selected(self, event=None):
        sel = self.iface_cb.get()
        # find first ip in map matching selection
        for name, ips in self.if_map.items():
            display = f"{name} ({', '.join(ips)})"
            if display == sel:
                ip = ips[0]
                self.bind_entry.delete(0, 'end')
                self.bind_entry.insert(0, ip)
                # re-validate pool warning
                try:
                    import ipaddress
                    pool_start = self.pool_start.get().strip() or "192.168.50.100"
                    pool_end = self.pool_end.get().strip() or "192.168.50.150"
                    ip_val = ipaddress.IPv4Address(ip)
                    start = ipaddress.IPv4Address(pool_start)
                    end = ipaddress.IPv4Address(pool_end)
                    if int(ip_val) < int(start) or int(ip_val) > int(end):
                        self.if_warn.config(text='Warning: interface IP not in pool range')
                    else:
                        self.if_warn.config(text='')
                except Exception:
                    self.if_warn.config(text='')
                break

    def _on_priv_toggle(self):
        if self.use_priv_var.get():
            if not is_admin():
                self.if_warn.config(text='Not Administrator — cannot bind port 67')
                self.logger('Privilege warning: not running as Administrator; port 67 will fail')
            else:
                self.if_warn.config(text='Running as Administrator; port 67 available')
        else:
            self.if_warn.config(text='')

    def relaunch_as_admin(self):
        """Relaunch the current script with administrator privileges."""
        if is_admin():
            self.logger('Already running as Administrator')
            messagebox.showinfo('Info', 'Already running as Administrator')
            return
        script = os.path.abspath(sys.argv[0])
        python = sys.executable
        try:
            if os.name == 'nt':
                # Windows: ShellExecute with runas verb
                import ctypes
                params = f'"{script}"'
                ctypes.windll.shell32.ShellExecuteW(None, 'runas', python, params, None, 1)
                self.logger('Relaunching as Administrator...')
                self.root.quit()
            else:
                # Unix-like: try sudo
                subprocess.Popen(['sudo', python, script])
                self.logger('Relaunching with sudo...')
                self.root.quit()
        except Exception as e:
            messagebox.showerror('Error', f'Failed to relaunch elevated: {e}')
