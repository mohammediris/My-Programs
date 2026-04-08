using System;
using System.Net;
using SubnetCalculator.Models;
namespace SubnetCalculator
{
    public class Calculator
    {
        public SubnetInfo CalculateSubnet(string ipAddress, string subnetMask)
        {
            var ip = IPAddress.Parse(ipAddress);
            var mask = IPAddress.Parse(subnetMask);
            var networkAddress = GetNetworkAddress(ip, mask);
            var broadcastAddress = GetBroadcastAddress(networkAddress, mask);
            var usableHosts = GetUsableHosts(networkAddress, broadcastAddress);

            return new SubnetInfo
            {
                NetworkAddress = networkAddress.ToString(),
                SubnetMask = subnetMask,
                BroadcastAddress = broadcastAddress.ToString(),
                UsableHosts = usableHosts
            };
        }

        private IPAddress GetNetworkAddress(IPAddress ip, IPAddress mask)
        {
            var ipBytes = ip.GetAddressBytes();
            var maskBytes = mask.GetAddressBytes();
            var networkBytes = new byte[ipBytes.Length];

            for (int i = 0; i < ipBytes.Length; i++)
            {
                networkBytes[i] = (byte)(ipBytes[i] & maskBytes[i]);
            }

            return new IPAddress(networkBytes);
        }

        private IPAddress GetBroadcastAddress(IPAddress networkAddress, IPAddress mask)
        {
            var networkBytes = networkAddress.GetAddressBytes();
            var maskBytes = mask.GetAddressBytes();
            var broadcastBytes = new byte[networkBytes.Length];

            for (int i = 0; i < networkBytes.Length; i++)
            {
                broadcastBytes[i] = (byte)(networkBytes[i] | ~maskBytes[i]);
            }

            return new IPAddress(broadcastBytes);
        }

        private int GetUsableHosts(IPAddress networkAddress, IPAddress broadcastAddress)
        {
            var networkBytes = networkAddress.GetAddressBytes();
            var broadcastBytes = broadcastAddress.GetAddressBytes();
            int usableHosts = 0;

            for (int i = 0; i < networkBytes.Length; i++)
            {
                usableHosts += (broadcastBytes[i] - networkBytes[i]);
            }

            return usableHosts - 2; // Subtracting network and broadcast addresses
        }

        public bool IsValidIPAddress(string ipAddress)
        {
            return IPAddress.TryParse(ipAddress, out _);
        }

        public bool IsValidSubnetMask(string subnetMask)
        {
            return IPAddress.TryParse(subnetMask, out _);
        }
    }
}