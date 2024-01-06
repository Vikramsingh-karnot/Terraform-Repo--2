#Fronted
#Creating the web app, pass in the app service plan ID
resource "azurerm_linux_web_app" "fe-webapp" {
  name                = "mywebappv"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_service_plan.fe-asp.location
  service_plan_id     = azurerm_service_plan.fe-asp.id

  site_config {
    minimum_tls_version = "1.2"
  }

  depends_on = [azurerm_service_plan.fe-asp]
}

#Backend 
#Storage Account
resource "azurerm_storage_account" "fn-storageaccount" {
  name                     = "fgfunctionappsa2023"
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_linux_function_app" "be-fnapp" {
  name                = "be-function-app"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location

  storage_account_name       = azurerm_storage_account.fn-storageaccount.name
  storage_account_access_key = azurerm_storage_account.fn-storageaccount.primary_access_key
  service_plan_id            = azurerm_service_plan.be-asp.id

  site_config {

    ip_restriction {
      virtual_network_subnet_id = azurerm_subnet.fe-subnet.id
      priority                  = 100
      name                      = "Frontend access only"
    }
    application_stack {
      python_version = 3.8
    }
  }
  identity {
    type = "SystemAssigned"
  }

  depends_on = [azurerm_storage_account.fn-storageaccount]
}

#vnet integration with backend
resource "azurerm_app_service_virtual_network_swift_connection" "be-vnet-integration" {
  app_service_id = azurerm_linux_function_app.be-fnapp.id
  subnet_id      = azurerm_subnet.be-subnet.id

  depends_on = [azurerm_subnet.be-subnet]
}

#vnet integration with fronted
resource "azurerm_app_service_virtual_network_swift_connection" "fe-vnet-integration" {
  app_service_id = azurerm_linux_web_app.fe-webapp.id
  subnet_id      = azurerm_subnet.fe-subnet.id

  depends_on = [azurerm_subnet.fe-subnet]
}