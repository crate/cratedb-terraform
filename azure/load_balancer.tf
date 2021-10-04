resource "azurerm_public_ip" "main" {
  name                = "PIP-${local.config.component_name}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  domain_name_label   = lower(local.config.component_name)
}

resource "azurerm_lb" "main" {
  name                = "LB-${local.config.component_name}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  frontend_ip_configuration {
    name                 = "publicIPAddress"
    public_ip_address_id = azurerm_public_ip.main.id
  }
}

resource "azurerm_lb_backend_address_pool" "main" {
  loadbalancer_id = azurerm_lb.main.id
  name            = "BackEndAddressPool"
}

resource "azurerm_lb_probe" "http" {
  resource_group_name = azurerm_resource_group.rg.name
  loadbalancer_id     = azurerm_lb.main.id
  name                = "crate-http-running-probe"
  port                = 4200
  number_of_probes    = 2
  protocol            = "Tcp"
  interval_in_seconds = 15
}

resource "azurerm_lb_probe" "postgresql" {
  resource_group_name = azurerm_resource_group.rg.name
  loadbalancer_id     = azurerm_lb.main.id
  name                = "crate-postgresql-running-probe"
  port                = 4200
  number_of_probes    = 2
  protocol            = "Tcp"
  interval_in_seconds = 15
}

resource "azurerm_lb_rule" "cratedb_http" {
  resource_group_name            = azurerm_resource_group.rg.name
  loadbalancer_id                = azurerm_lb.main.id
  name                           = "LB-CrateDB-Rule"
  protocol                       = "Tcp"
  frontend_port                  = 4200
  backend_port                   = 4200
  frontend_ip_configuration_name = "publicIPAddress"
  backend_address_pool_id        = azurerm_lb_backend_address_pool.main.id
  probe_id                       = azurerm_lb_probe.http.id
}

resource "azurerm_lb_rule" "cratedb_postgresql" {
  resource_group_name            = azurerm_resource_group.rg.name
  loadbalancer_id                = azurerm_lb.main.id
  name                           = "LB-PostgreSQL-Rule"
  protocol                       = "Tcp"
  frontend_port                  = 5432
  backend_port                   = 5432
  frontend_ip_configuration_name = "publicIPAddress"
  backend_address_pool_id        = azurerm_lb_backend_address_pool.main.id
  probe_id                       = azurerm_lb_probe.postgresql.id
}
