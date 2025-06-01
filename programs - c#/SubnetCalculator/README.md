# Subnet Calculator

## Overview
The Subnet Calculator is a native C# application designed to assist users in performing subnet calculations. It provides functionalities to calculate subnet masks, determine network and broadcast addresses, and validate IP addresses.

## Features
- Calculate subnet masks based on CIDR notation.
- Determine network and broadcast addresses for given IP addresses and subnet masks.
- Validate IP addresses and subnet masks.
- User-friendly interface for easy input and output of results.

## Project Structure
```
SubnetCalculator
├── SubnetCalculator.sln          # Solution file for the project
├── SubnetCalculator              # Main project directory
│   ├── Program.cs                # Entry point of the application
│   ├── Calculator.cs             # Contains methods for subnet calculations
│   ├── Models                    # Directory for model classes
│   │   └── SubnetInfo.cs         # Class holding subnet information
│   ├── Views                     # Directory for UI components
│   │   └── MainForm.cs           # Main user interface of the application
│   └── Properties                # Directory for assembly properties
│       └── AssemblyInfo.cs       # Assembly metadata
└── README.md                     # Documentation for the project
```

## Getting Started

### Prerequisites
- .NET SDK (version 5.0 or later)

### Building the Application
1. Open a terminal and navigate to the project directory.
2. Run the following command to build the application:
   ```
   dotnet build
   ```

### Running the Application
1. After building, run the application using the following command:
   ```
   dotnet run --project SubnetCalculator
   ```

## Usage
- Launch the application and enter the required IP address and subnet mask.
- Click on the calculate button to view the results, including network address, broadcast address, and usable hosts.

## Contributing
Contributions are welcome! Please feel free to submit a pull request or open an issue for any enhancements or bug fixes.

## License
This project is licensed under the MIT License. See the LICENSE file for more details.