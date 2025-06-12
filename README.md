# terraform-learn

Learning terraform basics

# Azure Terraform Infrastructure 

## Network Architecture

### High-Level Network Diagram
```mermaid
graph TB
    Internet((Internet)) --> |Public IP| LB[Azure Load Balancer]
    
    subgraph Azure VNet [Azure Virtual Network 10.0.0.0/16]
        subgraph Private Subnet [Private Subnet 10.0.1.0/24]
            VM[Ubuntu VM<br/>10.0.1.x] --> |NIC| NSG[Network Security Group]
            VM --> |OS Disk| OS[Managed Disk]
            VM --> |Data Disk| WP[WordPress Disk]
            VM --> |Data Disk| DB[MySQL Disk]
        end
        
        subgraph NSG Rules [Security Rules]
            SSH[SSH:22<br/>Restricted IPs] --> NSG
            HTTP[HTTP:80<br/>Any] --> NSG
            HTTPS[HTTPS:443<br/>Any] --> NSG
        end
    end

    style Internet fill:#f9f,stroke:#333,stroke-width:2px
    style Azure VNet fill:#e1f5fe,stroke:#01579b,stroke-width:2px
    style Private Subnet fill:#e8f5e9,stroke:#2e7d32,stroke-width:2px
    style NSG Rules fill:#fff3e0,stroke:#e65100,stroke-width:2px
    style VM fill:#fce4ec,stroke:#c2185b,stroke-width:2px
```

### Network Flow Diagram
```mermaid
flowchart LR
    subgraph External [External Access]
        Client[Client] --> |1. HTTP/HTTPS| Internet
        Admin[Admin] --> |2. SSH| Internet
    end

    subgraph Azure [Azure Infrastructure]
        Internet --> |3. Traffic| NSG[Network Security Group]
        
        subgraph Rules [NSG Rules Evaluation]
            NSG --> |4a. Port 80/443| HTTP[HTTP/HTTPS Rule]
            NSG --> |4b. Port 22| SSH[SSH Rule]
            HTTP --> |5a. Allowed| VM[Virtual Machine]
            SSH --> |5b. IP Check| IP{IP Allowed?}
            IP --> |Yes| VM
            IP --> |No| Block[Blocked]
        end

        VM --> |6. Internal| Subnet[Private Subnet]
        Subnet --> |7. VNet| VNet[Virtual Network]
    end

    style External fill:#f5f5f5,stroke:#333,stroke-width:2px
    style Azure fill:#e3f2fd,stroke:#1565c0,stroke-width:2px
    style Rules fill:#fff3e0,stroke:#e65100,stroke-width:2px
    style IP fill:#ffebee,stroke:#c62828,stroke-width:2px
```

### IP Address Allocation
```mermaid
graph TD
    subgraph VNet [Virtual Network 10.0.0.0/16]
        subgraph Subnet [Private Subnet 10.0.1.0/24]
            Reserved1[10.0.1.0<br/>Network Address] --> Available
            Reserved2[10.0.1.1<br/>Azure Gateway] --> Available
            Reserved3[10.0.1.2-3<br/>Azure DNS] --> Available
            Available[10.0.1.4-254<br/>Available for VMs] --> Reserved4
            Reserved4[10.0.1.255<br/>Broadcast] --> Available
        end
    end

    style VNet fill:#e3f2fd,stroke:#1565c0,stroke-width:2px
    style Subnet fill:#e8f5e9,stroke:#2e7d32,stroke-width:2px
    style Available fill:#fce4ec,stroke:#c2185b,stroke-width:2px
    style Reserved1,Reserved2,Reserved3,Reserved4 fill:#fff3e0,stroke:#e65100,stroke-width:2px
```

### Security Rules Flow
```mermaid
graph TD
    subgraph NSG [Network Security Group Rules]
        direction TB
        Inbound[Inbound Traffic] --> Rule1[Rule 100: SSH]
        Inbound --> Rule2[Rule 110: HTTP]
        Inbound --> Rule3[Rule 120: HTTPS]
        
        Rule1 --> Check1{Source IP<br/>Allowed?}
        Rule2 --> Check2{Port 80?}
        Rule3 --> Check3{Port 443?}
        
        Check1 -->|Yes| Allow1[Allow SSH]
        Check1 -->|No| Deny1[Deny SSH]
        Check2 -->|Yes| Allow2[Allow HTTP]
        Check2 -->|No| Deny2[Deny HTTP]
        Check3 -->|Yes| Allow3[Allow HTTPS]
        Check3 -->|No| Deny3[Deny HTTPS]
    end

    style NSG fill:#e3f2fd,stroke:#1565c0,stroke-width:2px
    style Inbound fill:#f5f5f5,stroke:#333,stroke-width:2px
    style Rule1,Rule2,Rule3 fill:#fff3e0,stroke:#e65100,stroke-width:2px
    style Check1,Check2,Check3 fill:#ffebee,stroke:#c62828,stroke-width:2px
    style Allow1,Allow2,Allow3 fill:#e8f5e9,stroke:#2e7d32,stroke-width:2px
    style Deny1,Deny2,Deny3 fill:#fce4ec,stroke:#c2185b,stroke-width:2px
```

### Resource Dependencies
```mermaid
graph TD
    A[Resource Group] --> B[Virtual Network]
    B --> C[Private Subnet]
    A --> D[Network Security Group]
    D --> E[NSG Rules]
    C --> F[Network Interface]
    A --> G[Virtual Machine]
    F --> G
    A --> H[Managed Disks]
    G --> H
```

## Detailed Resource Analysis

### 2. Virtual Network (`azurerm_virtual_network`)
```hcl
resource "azurerm_virtual_network" "vnet" {
  name                = "northerntool-vnet"
  address_space       = [var.vnet_cidr]  # 10.0.0.0/16
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  tags                = local.common_tags
}
```
- **CIDR Block**: 10.0.0.0/16 provides 65,536 IP addresses (2^16)
- **Subnetting**: Currently using 10.0.1.0/24 (256 addresses) for private subnet
- **IP Allocation**: 
  - First 4 IPs and last IP are reserved by Azure
  - Available IPs: 10.0.1.4 to 10.0.1.254


### 3. Network Security Group (`azurerm_network_security_group`)
```hcl
resource "azurerm_network_security_group" "nsg" {
  # ... configuration ...
  security_rule {
    name                       = "SSH"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = var.allowed_ssh_ip
    destination_address_prefix = "*"
  }
  # ... other rules ...
}
```
- **Rule Priority**: 
  - Lower numbers (100-4096) are evaluated first
  - Current priorities: SSH(100), HTTP(110), HTTPS(120)
- **Default Rules**:
  - All inbound traffic from VNet is allowed
  - All outbound traffic is allowed
  - All other traffic is denied
- **Rule Evaluation**:
  1. Process rules in priority order
  2. Stop at first match
  3. If no match, apply default rule

### 4. Virtual Machine (`azurerm_linux_virtual_machine`)
```hcl
resource "azurerm_linux_virtual_machine" "vm" {
  name                = "northerntool-vm"
  size                = var.vm_size  # Standard_B2s
  admin_username      = "northernadmin"
  # ... other configuration ...
}
```
- **VM Specifications**:
  - Size: Standard_B2s (2 vCPUs, 4 GB RAM)
  - OS: Ubuntu 20.04 LTS
  - Disk: 30GB OS disk (Standard_LRS)
- **Authentication**:
  - Password authentication disabled
  - SSH key-based authentication only
  - Key path configurable via variable
- **Performance Considerations**:
  - B-series VMs are burstable
  - Good for development/testing
  - Consider upgrading for production workloads

### 5. Managed Disks
```hcl
resource "azurerm_managed_disk" "wp_uploads" {
  name                 = "wp-data"
  storage_account_type = var.disk_storage_type
  disk_size_gb         = var.wp_disk_size
  # ... other configuration ...
}
```
- **Disk Types**:
  - OS Disk: Standard_LRS (30GB)
  - WordPress Data: Configurable (default 10GB)
  - MySQL Data: Configurable (default 10GB)
- **Storage Options**:
  - Standard_LRS: Basic storage, single region
  - Premium_LRS: High performance, single region
  - StandardSSD_LRS: Better performance than Standard_LRS
- **Performance Considerations**:
  - IOPS: Varies by disk size and type
  - Throughput: Varies by disk size and type
  - Consider Premium_LRS for production databases

## Code Organization

```
terraform/
├── environment/
│   └── prod/
│       ├── main.tf           # Core infrastructure
│       ├── variables.tf      # Input variables
│       ├── outputs.tf        # Output values
│       ├── provider.tf       # Provider config
│       └── terraform.tfvars  # Local variables (gitignored)
├── modules/                  # Future: reusable modules
└── README.md
```

## Troubleshooting Guide

### Common Issues

1. **Terraform State Issues**
   ```bash
   # Reset state if corrupted
   terraform state rm <resource>
   terraform import <resource> <resource_id>
   ```

2. **VM Connection Issues**
   ```bash
   # Verify NSG rules
   az network nsg rule list --resource-group northerntool-rg --nsg-name northerntool-nsg

   # Check VM status
   az vm show --resource-group northerntool-rg --name northerntool-vm --show-details
   ```

3. **Disk Performance Issues**
   ```bash
   # Check disk metrics
   az monitor metrics list --resource <disk_id> --metric "Disk Read Operations/Sec"
   ```

### Debugging Commands

```bash
# Show Terraform state
terraform state list
terraform state show azurerm_linux_virtual_machine.vm

# Validate configuration
terraform validate

# Show execution plan
terraform plan -var-file=terraform.tfvars

# Force unlock state if needed
terraform force-unlock <lock_id>
```
