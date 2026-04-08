# Modern Subnet Scanner

A modern GUI subnet scanner that scans all well-known ports concurrently and displays the scanning progress. This application is built using Python and Tkinter, providing an easy-to-use interface for network scanning.

## Features

- Scans a specified subnet for open ports.
- Supports scanning of well-known ports (HTTP, HTTPS, SSH, etc.).
- Displays real-time scanning progress.
- User-friendly graphical interface.

## Project Structure

```
modern-subnet-scanner
├── src
│   ├── main.py        # Entry point of the application
│   ├── scanner.py     # Scanning logic
│   ├── gui.py         # GUI setup
│   └── utils.py       # Utility functions
├── requirements.txt    # Project dependencies
└── README.md           # Project documentation
```

## Installation

1. Clone the repository:
   ```
   git clone <repository-url>
   cd modern-subnet-scanner
   ```

2. Install the required dependencies:
   ```
   pip install -r requirements.txt
   ```

## Usage

1. Run the application:
   ```
   python src/main.py
   ```

2. Enter the subnet in CIDR format (e.g., 192.168.1.0/24).
3. Select the ports you wish to scan.
4. Click the "Scan" button to start scanning.
5. View the results and progress in the GUI.

## Requirements

- Python 3.x
- Tkinter (usually included with Python installations)
- Any additional libraries specified in `requirements.txt`.

## License

This project is licensed under the MIT License - see the LICENSE file for details.