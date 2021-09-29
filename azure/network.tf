resource "azurerm_virtual_network" "vn" {
  name = "VN-${local.config.component_name}"
  location = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  address_space = [local.config.cratedb_ip_network]
}

resource "azurerm_subnet" "sn" {
  name = "SN-${local.config.component_name}-VM"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vn.name
  address_prefixes = [local.config.cratedb_ip_mask]
}

resource "azurerm_network_security_group" "nsg" {
  name = "NSG-${local.config.component_name}"
  location = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  security_rule {
    name  = "CrateDB-HTTP"
    priority = 100
    direction = "Inbound"
    access = "Allow"
    protocol = "Tcp"
    source_port_range = "*"
    destination_port_range = "4200"
    source_address_prefix = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name = "CrateDB-PostgreSQL"
    priority = 101
    direction = "Inbound"
    access = "Allow"
    protocol = "Tcp"
    source_port_range = "*"
    destination_port_range = "5432"
    source_address_prefix = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name = "SSH"
    priority = 102
    direction = "Inbound"
    access = "Allow"
    protocol = "Tcp"
    source_port_range = "*"
    destination_port_range = "22"
    source_address_prefix = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "sn_nsg" {
  subnet_id = azurerm_subnet.sn.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}
