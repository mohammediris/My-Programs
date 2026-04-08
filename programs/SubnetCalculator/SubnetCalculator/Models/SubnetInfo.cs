using System;

namespace SubnetCalculator.Models
{
    public class SubnetInfo
    {
        public string NetworkAddress { get; set; }
        public string SubnetMask { get; set; }
        public string BroadcastAddress { get; set; }
        public int UsableHosts { get; set; }
    }
}