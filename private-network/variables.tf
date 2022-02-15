variable "base_name" {
    type = string
    description = "base name for all resources"
}

variable "location" {
    type = string
    description = "Location to deploy the virtual network"
}

variable "vm_username" {
    type = string
    description = "Username of the VM deployed into the VNet"
}

variable "vm_password" {
    type = string
    description = "Password of the VM deployed into the VNet"
}

variable "vm_size" {
    type = string
    description = "Size of the Virtual Machine to deploy into the VNet"
    default = "Standard_DS1_v2"
}

//variable "virtual_network_gateway_sku" {
//    type = string
//    description = "Sku of the Virtual Network Gateway in the VNet"
//    default = "VpnGw1"
//}

variable "virtual_network_address_space" {
    type = list(string)
    description = "Address space of the Virtual Network"
    default = ["10.100.0.0/16"]
}

variable "gateway_subnet_address_prefix" {
    type = list(string)
    description = "Prefix of the Virtual Network subnet"
    default = ["10.100.0.0/20"]
}

variable "main_subnet_address_prefix" {
    type = list(string)
    description = "Prefix of the Virtual Network subnet"
    default = ["10.100.16.0/20"]
}