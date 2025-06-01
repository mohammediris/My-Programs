# Ping Multi GUI

## Overview
Ping Multi GUI is a Python application that allows users to ping multiple IP addresses concurrently through a modern graphical user interface (GUI). This tool is useful for network administrators and anyone needing to check the availability of multiple devices on a network.

## Features
- Concurrently ping multiple IP addresses.
- User-friendly GUI for easy interaction.
- Displays ping results in real-time.

## Project Structure
```
ping-multi-gui
├── src
│   ├── main.py        # Entry point of the application
│   ├── gui.py         # Contains the GUI layout and behavior
│   ├── ping.py        # Handles the pinging of IP addresses
│   └── utils.py       # Utility functions for IP validation
├── requirements.txt    # Lists the project dependencies
└── README.md           # Project documentation
```

## Requirements
To run this application, you need to install the following dependencies:

- Python 3.x
- tkinter (for GUI)
- asyncio or threading (for concurrent tasks)

You can install the required packages by running:
```
pip install -r requirements.txt
```

## Running the Application
1. Clone the repository:
   ```
   git clone https://github.com/yourusername/ping-multi-gui.git
   ```
2. Navigate to the project directory:
   ```
   cd ping-multi-gui
   ```
3. Install the required dependencies:
   ```
   pip install -r requirements.txt
   ```
4. Run the application:
   ```
   python src/main.py
   ```

## Usage
- Enter the IP addresses you want to ping in the provided input field.
- Click the "Ping" button to start the pinging process.
- View the results displayed in the GUI.

## Contributing
Contributions are welcome! Please feel free to submit a pull request or open an issue for any suggestions or improvements.

## License
This project is licensed under the MIT License. See the LICENSE file for more details.