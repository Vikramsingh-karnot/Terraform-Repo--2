#create random password
resource "random_password" "randompassword" {
  length           = 16
  special          = true
  override_special = "!@#$%&*(){}:^?><"
}

#Create Key Vault Secret
resource "azurerm_key_vault_secret" "sqladminpassword" {
  name         = "sqladmin"
  value        = random_password.randompassword.result
  key_vault_id = azurerm_key_vault.mykeyvault.id
  content_type = "text/plain"
  depends_on   = [azurerm_key_vault.mykeyvault]
}

#creating azure sql server
resource "azurerm_mysql_server" "azuresql" {
  name                = "mysqlserverv"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  administrator_login          = "mysqladmin"
  administrator_login_password = random_password.randompassword.result

  sku_name   = "B_Gen5_2"
  storage_mb = 5120
  version    = "5.7"

  auto_grow_enabled                 = true
  backup_retention_days             = 7
  geo_redundant_backup_enabled      = false
  infrastructure_encryption_enabled = false
  public_network_access_enabled     = true
  ssl_enforcement_enabled           = true
  ssl_minimal_tls_version_enforced  = "TLS1_2"
}

resource "azurerm_mssql_database" "my-database" {
  name           = "fg-db"
  server_id      = azurerm_mysql_server.azuresql.id
  collation      = "SQL_Latin1_General_CP1_CI_AS"
  max_size_gb    = 2
  read_scale     = false
  sku_name       = "S0"
  zone_redundant = false

  tags = {
    Application = "myapp-demo"
    Env         = "Prod"
  }
}


#add subnet from the backend
resource "azurerm_mssql_virtual_network_rule" "allow-be" {
  name       = "be-sql-vnet-rule"
  server_id  = azurerm_mysql_server.azuresql.id
  subnet_id  = azurerm_subnet.be-subnet.id
  depends_on = [azurerm_mysql_server.azuresql]
}

resource "azurerm_key_vault_secret" "sqldb_cnxn" {
  name         = "fgsqldbconstring"
  value        = "Driver={ODBC Driver 18 for SQL Server};Server=tcp:fg-sqldb-prod.database.windows.net,1433;Database=fg-db;Uid=4adminu$er;Pwd=${random_password.randompassword.result};Encrypt=yes;TrustServerCertificate=no;Connection Timeout=30;"
  key_vault_id = azurerm_key_vault.mykeyvault.id
  depends_on = [
    azurerm_mssql_database.my-database, azurerm_key_vault_access_policy.kv_access_policy_01, azurerm_key_vault_access_policy.kv_access_policy_02, azurerm_key_vault_access_policy.kv_access_policy_03
  ]
}