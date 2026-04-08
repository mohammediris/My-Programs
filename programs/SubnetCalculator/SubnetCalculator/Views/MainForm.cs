using System;
using System.Windows.Forms;

namespace SubnetCalculator.Views
{
    public partial class MainForm : Form
    {
        public MainForm()
        {
            InitializeComponent();
        }

        private void btnCalculate_Click(object sender, EventArgs e)
        {
            string ipAddress = txtIPAddress.Text;
            string subnetMask = txtSubnetMask.Text;

            try
            {
                var calculator = new Calculator();
                var subnetInfo = calculator.CalculateSubnet(ipAddress, subnetMask);

                lblResult.Text = $"Network: {subnetInfo.NetworkAddress}\n" +
                                 $"Mask: {subnetInfo.SubnetMask}\n" +
                                 $"Broadcast: {subnetInfo.BroadcastAddress}\n" +
                                 $"Usable Hosts: {subnetInfo.UsableHosts}";
            }
            catch (Exception ex)
            {
                lblResult.Text = "Error: " + ex.Message;
            }
        }

        private void InitializeComponent()
        {
            this.txtIPAddress = new System.Windows.Forms.TextBox();
            this.txtSubnetMask = new System.Windows.Forms.TextBox();
            this.btnCalculate = new System.Windows.Forms.Button();
            this.lblResult = new System.Windows.Forms.Label();
            this.SuspendLayout();
            // 
            // txtIPAddress
            // 
            this.txtIPAddress.Location = new System.Drawing.Point(12, 12);
            this.txtIPAddress.Name = "txtIPAddress";
            this.txtIPAddress.Size = new System.Drawing.Size(260, 20);
            this.txtIPAddress.TabIndex = 0;
            this.txtIPAddress.PlaceholderText = "Enter IP Address";
            // 
            // txtSubnetMask
            // 
            this.txtSubnetMask.Location = new System.Drawing.Point(12, 38);
            this.txtSubnetMask.Name = "txtSubnetMask";
            this.txtSubnetMask.Size = new System.Drawing.Size(260, 20);
            this.txtSubnetMask.TabIndex = 1;
            this.txtSubnetMask.PlaceholderText = "Enter Subnet Mask";
            // 
            // btnCalculate
            // 
            this.btnCalculate.Location = new System.Drawing.Point(12, 64);
            this.btnCalculate.Name = "btnCalculate";
            this.btnCalculate.Size = new System.Drawing.Size(75, 23);
            this.btnCalculate.TabIndex = 2;
            this.btnCalculate.Text = "Calculate";
            this.btnCalculate.UseVisualStyleBackColor = true;
            this.btnCalculate.Click += new System.EventHandler(this.btnCalculate_Click);
            // 
            // lblResult
            // 
            this.lblResult.AutoSize = true;
            this.lblResult.Location = new System.Drawing.Point(12, 100);
            this.lblResult.Name = "lblResult";
            this.lblResult.Size = new System.Drawing.Size(0, 13);
            this.lblResult.TabIndex = 3;
            // 
            // MainForm
            // 
            this.ClientSize = new System.Drawing.Size(284, 131);
            this.Controls.Add(this.lblResult);
            this.Controls.Add(this.btnCalculate);
            this.Controls.Add(this.txtSubnetMask);
            this.Controls.Add(this.txtIPAddress);
            this.Name = "MainForm";
            this.Text = "Subnet Calculator";
            this.ResumeLayout(false);
            this.PerformLayout();
        }

        private System.Windows.Forms.TextBox txtIPAddress;
        private System.Windows.Forms.TextBox txtSubnetMask;
        private System.Windows.Forms.Button btnCalculate;
        private System.Windows.Forms.Label lblResult;
    }
}