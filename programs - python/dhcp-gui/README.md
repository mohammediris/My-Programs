Simple Python DHCP GUI server demo

Run the GUI and press "Start Server" to begin listening on a non-privileged port (default 6767).
Use "Simulate Client" to generate a DISCOVER -> OFFER -> REQUEST -> ACK flow for demonstration.

Notes:
- This is a minimal educational DHCP server (not production-ready).
- Default port is non-privileged (6767) so admin rights aren't required.

Usage:
```bash
python src/main.py
```
