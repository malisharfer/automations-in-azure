resource "azurerm_storage_account" "vnet_storage_account" {
  name                     = var.vnet_storage_account_name
  resource_group_name      = var.rg_name
  location                 = var.rg_location
  account_tier             = "Standard"
  account_replication_type = "LRS"

}

resource "azurerm_storage_account_network_rules" "network_rules" {
  storage_account_id    = azurerm_storage_account.vnet_storage_account.id
  default_action             = "Deny"
  virtual_network_subnet_ids = [var.vnet_subnet_id]
  ip_rules                   = ["84.110.136.18"]
}

data "azurerm_key_vault" "key_vault" {
  name                = var.key_vault_name
  resource_group_name = var.key_vault_resource_group_name
}

resource "azurerm_key_vault_secret" "key_vault_secret" {
  name         = var.key_vault_secret_name
  value        = azurerm_storage_account.vnet_storage_account.primary_connection_string
  key_vault_id = data.azurerm_key_vault.key_vault.id
}

resource "azurerm_service_plan" "service_plan" {
  name                = var.app_service_plan_name[count.index]
  resource_group_name = azurerm_storage_account.vnet_storage_account.resource_group_name
  location            = azurerm_storage_account.vnet_storage_account.location
  os_type             = "Linux"
  sku_name            = "P1v2"

  count = length(var.app_service_plan_name)
}

resource "azurerm_linux_function_app" "linux_function_app" {
  name                = var.function_app_name[count.index]
  resource_group_name = azurerm_storage_account.vnet_storage_account.resource_group_name
  location            = azurerm_storage_account.vnet_storage_account.location

  storage_account_name       = azurerm_storage_account.vnet_storage_account.name
  storage_account_access_key = azurerm_storage_account.vnet_storage_account.primary_access_key
  service_plan_id            = azurerm_service_plan.service_plan[count.index].id
  functions_extension_version = "~4"

  app_settings = count.index==0 ? {
    FUNCTIONS_WORKER_RUNTIME = "python"

    DESIRED_TIME_PERIOD_SINCE_LAST_RETRIEVAL_FOR_CHECK_LAST_FETCH=""
    TIME_INDEX_FOR_CHECK_LAST_FETCH=""
    WORKSPACE_ID=" "
    https_only                          = true
    DOCKER_REGISTRY_SERVER_URL          = var.DOCKER_REGISTRY_SERVER_URL
    DOCKER_REGISTRY_SERVER_USERNAME     = var.DOCKER_REGISTRY_SERVER_USERNAME
    DOCKER_REGISTRY_SERVER_PASSWORD     = var.DOCKER_REGISTRY_SERVER_PASSWORD
    WEBSITES_ENABLE_APP_SERVICE_STORAGE = false
  } : count.index==1 ? {
    FUNCTIONS_WORKER_RUNTIME = "python"
    
    DOCUMENTATION_TABLE = " "
    SECRET = azurerm_key_vault_secret.key_vault_secret.name
    KEYVAULT_URI = data.azurerm_key_vault.key_vault.vault_uri
    https_only                          = true
    DOCKER_REGISTRY_SERVER_URL          = var.DOCKER_REGISTRY_SERVER_URL
    DOCKER_REGISTRY_SERVER_USERNAME     = var.DOCKER_REGISTRY_SERVER_USERNAME
    DOCKER_REGISTRY_SERVER_PASSWORD     = var.DOCKER_REGISTRY_SERVER_PASSWORD
    WEBSITES_ENABLE_APP_SERVICE_STORAGE = false
  } : count.index==2 ? {
    FUNCTIONS_WORKER_RUNTIME = "python"

    ESSENTIAL_TAG=" "
    https_only                          = true
    DOCKER_REGISTRY_SERVER_URL          = var.DOCKER_REGISTRY_SERVER_URL
    DOCKER_REGISTRY_SERVER_USERNAME     = var.DOCKER_REGISTRY_SERVER_USERNAME
    DOCKER_REGISTRY_SERVER_PASSWORD     = var.DOCKER_REGISTRY_SERVER_PASSWORD
    WEBSITES_ENABLE_APP_SERVICE_STORAGE = false
  }: count.index==3 ? {
    FUNCTIONS_WORKER_RUNTIME = "python"
 
    DESIRED_TIME_PERIOD_SINCE_LAST_RETRIEVAL_FOR_CHECK_LAST_FETCH = " "
    DESIRED_TIME_PERIOD_SINCE_LAST_RETRIEVAL_FOR_CHECK_USED_CAPACITY = " "
    # TIME_INDEX="days"/"weeks"/"months"/"years"
    TIME_INDEX_FOR_CHECK_LAST_FETCH=" "
    TIME_INDEX_FOR_CHECK_USED_CAPACITY=" "
    FREQ_AUTOMATION_TEST_TYPE=" "
    FREQ_AUTOMATION_TEST_NUMBER=" "
    DOCUMENTATION_TABLE =" "
    HTTP_TRIGGER_URL=" "
    ALERTS_DOCUMENTATION=" "
    DOCUMENTATION_STORAGE_NAME=" "
    SECRET = azurerm_key_vault_secret.key_vault_secret.name
    KEYVAULT_URI = data.azurerm_key_vault.key_vault.vault_uri
    https_only                          = true
    DOCKER_REGISTRY_SERVER_URL          = var.DOCKER_REGISTRY_SERVER_URL
    DOCKER_REGISTRY_SERVER_USERNAME     = var.DOCKER_REGISTRY_SERVER_USERNAME
    DOCKER_REGISTRY_SERVER_PASSWORD     = var.DOCKER_REGISTRY_SERVER_PASSWORD
    WEBSITES_ENABLE_APP_SERVICE_STORAGE = false
  } : count.index==4 ? {
    FUNCTIONS_WORKER_RUNTIME = "python"

    HTTP_TRIGGER_URL=" "
    MAIN_MANAGER=" "
    DOCUMENTATION_TABLE =" "
    DELETED_ACCOUNTS_TABLE=" "

    KEYVAULT_URI = data.azurerm_key_vault.key_vault.vault_uri
    SECRET = azurerm_key_vault_secret.key_vault_secret.name
    SECRET_EXCEL = var.key_vault_secret_excel_name
    https_only                          = true
    DOCKER_REGISTRY_SERVER_URL          = var.DOCKER_REGISTRY_SERVER_URL
    DOCKER_REGISTRY_SERVER_USERNAME     = var.DOCKER_REGISTRY_SERVER_USERNAME
    DOCKER_REGISTRY_SERVER_PASSWORD     = var.DOCKER_REGISTRY_SERVER_PASSWORD
    WEBSITES_ENABLE_APP_SERVICE_STORAGE = false
  }: {}

  site_config {
    always_on         = true
    application_stack {
      docker {
        registry_url = var.DOCKER_REGISTRY_SERVER_URL
        image_name = var.IMAGE_NAME
        image_tag = var.IMAGE_TAG
        registry_username = var.DOCKER_REGISTRY_SERVER_USERNAME
        registry_password = var.DOCKER_REGISTRY_SERVER_PASSWORD
      }
    }
  } 

  identity {
    type = "SystemAssigned"
  }
  count= length(var.function_app_name)
}

resource "azurerm_linux_function_app_slot" "linux_function_app_slot" {
  name                       = "development"
  function_app_id            = azurerm_linux_function_app.linux_function_app[count.index].id
  storage_account_name       = azurerm_storage_account.vnet_storage_account.name
  storage_account_access_key = azurerm_storage_account.vnet_storage_account.primary_access_key
  site_config {
    always_on         = true
    application_stack {
      docker {
        registry_url = var.DOCKER_REGISTRY_SERVER_URL
        image_name = var.IMAGE_NAME
        image_tag = var.IMAGE_TAG
        registry_username = var.DOCKER_REGISTRY_SERVER_USERNAME
        registry_password = var.DOCKER_REGISTRY_SERVER_PASSWORD
      }
    }
  }

  count = length(var.function_app_name)
}

resource "azurerm_logic_app_workflow" "logic_app_workflow" {
  name                = var.logic_app_workflow_name
  location            = var.rg_location
  resource_group_name = var.rg_name

  workflow_parameters = {
    "workflows_logic_app_name" : "{ \"defaultValue\":\"${var.logic_app_workflow_name}\", \"type\" : \"string\"}"
    "sites_func_get_last_fetch_time_for_each_storage_account_externalid": "{\"defaultValue\": \"${azurerm_linux_function_app.linux_function_app[0].id}\",\"type\": \"string\"}"
    "sites_func_get_subscription_list_externalid": "{\"defaultValue\": \"${azurerm_linux_function_app.linux_function_app[1].id}\", \"type\": \"string\"}"
    "sites_func_get_storage_list_by_subscription_externalid": "{\"defaultValue\": \"${azurerm_linux_function_app.linux_function_app[2].id}\",\"type\": \"string\" }"
    "sites_func_test_storage_externalid": "{ \"defaultValue\":\"${azurerm_linux_function_app.linux_function_app[3].id}\", \"type\": \"string\"}"
    "sites_func_sending_excel_by_email_and_mark_storages_for_deletion_externalid": "{\"defaultValue\": \"${azurerm_linux_function_app.linux_function_app[4].id}\",\"type\": \"string\" }"
    "location":"{\"defaultValue\": \"${var.rg_location}\",\"type\": \"string\" }"
    "frequency":"{\"defaultValue\": \"${var.FREQ_AUTOMATION_TEST_TYPE}\",\"type\": \"string\",\"allowedValues\": [\"Month\",\"Week\",\"Day\",\"Hour\",\"Minute\",\"Second\"]}"
    "interval": "{ \"defaultValue\": ${var.FREQ_AUTOMATION_TEST_NUMBER}, \"type\": \"int\" }"
  }
}

data "azurerm_client_config" "current_client" {}

resource "azurerm_key_vault_access_policy" "principal" {
  key_vault_id = data.azurerm_key_vault.key_vault.id
  tenant_id    = data.azurerm_client_config.current_client.tenant_id
  object_id    = azurerm_linux_function_app.linux_function_app[count.index].identity[0].principal_id

  key_permissions = [
    "Get", "List", "Encrypt", "Decrypt"
  ]

  secret_permissions = [
    "Get",
  ]

  count = length(var.function_app_name)

}