resource "random_password" "cratedb_password" {
  length           = 16
  special          = true
  override_special = "_%@"
}

resource "tls_private_key" "ssl" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "tls_self_signed_cert" "ssl" {
  private_key_pem = tls_private_key.ssl.private_key_pem

  # Set to two years. If the number is too high, there appears to be an overflow resulting in a date in the past.
  validity_period_hours = 17532

  subject {
    organization = var.config.team
  }

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
  ]
}

data "cloudinit_config" "config" {
  gzip          = true
  base64_encode = true

  # Cloud Init script for initializing CrateDB
  part {
    filename     = "init.cfg"
    content_type = "text/cloud-config"
    content = templatefile("${path.module}/scripts/cloud-init-cratedb.tftpl",
      {
        crate_user            = local.config.crate_username
        crate_pass            = random_password.cratedb_password.result
        crate_heap_size       = var.crate.heap_size_gb
        crate_cluster_name    = var.crate.cluster_name
        crate_cluster_size    = var.crate.cluster_size
        crate_nodes_ips       = indent(12, yamlencode(azurerm_network_interface.crate[*].private_ip_address))
        crate_ssl_enable      = var.crate.ssl_enable
        crate_ssl_certificate = base64encode(tls_self_signed_cert.ssl.cert_pem)
        crate_ssl_private_key = base64encode(tls_private_key.ssl.private_key_pem)
      }
    )
  }
}

resource "azurerm_public_ip" "ip" {
  count               = var.crate.cluster_size
  name                = "IP-${local.config.component_name}-cratevm-${count.index}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"

  sku = "Standard"
}

resource "azurerm_network_interface" "crate" {
  count               = var.crate.cluster_size
  name                = "NIC-${local.config.component_name}-cratevm-${count.index}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "default"
    subnet_id                     = azurerm_subnet.sn.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.ip[count.index].id
  }
}

resource "azurerm_network_interface_backend_address_pool_association" "main" {
  count                   = var.crate.cluster_size
  network_interface_id    = azurerm_network_interface.crate[count.index].id
  ip_configuration_name   = "default"
  backend_address_pool_id = azurerm_lb_backend_address_pool.main.id
}

resource "azurerm_linux_virtual_machine" "crate" {
  count = var.crate.cluster_size

  name                = "VM-CrateDB-${local.config.component_name}-${count.index}"
  computer_name       = "node-${count.index}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  zone                = var.config.zone
  size                = var.vm.size

  network_interface_ids = [azurerm_network_interface.crate[count.index].id]

  admin_username                  = var.vm.user
  disable_password_authentication = true
  custom_data                     = data.cloudinit_config.config.rendered

  source_image_reference {
    publisher = "canonical"
    offer     = "ubuntu-24_04-lts"
    sku       = "server"
    version   = "latest"
  }

  os_disk {
    name                 = "OSdisk-crate-${count.index}"
    caching              = "ReadWrite"
    storage_account_type = "StandardSSD_LRS"
  }

  admin_ssh_key {
    username   = var.vm.user
    public_key = file(var.ssh_public_key_path)
  }

  tags = {
    environment = local.config.environment
  }
}

resource "azurerm_managed_disk" "data_disk" {
  count = var.crate.cluster_size

  name                = "DataDisk-${count.index}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  zone                = var.config.zone

  storage_account_type = var.vm.storage_account_type
  create_option        = "Empty"
  disk_size_gb         = var.vm.disk_size_gb
}

resource "azurerm_virtual_machine_data_disk_attachment" "data_disk_attachment" {
  count = var.crate.cluster_size

  managed_disk_id    = azurerm_managed_disk.data_disk[count.index].id
  virtual_machine_id = azurerm_linux_virtual_machine.crate[count.index].id
  lun                = 1
  # Disk caching is not supported by Azure for >= 4 TiB
  caching = var.vm.disk_size_gb >= 4000 ? "None" : "ReadWrite"
}
