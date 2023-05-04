@description('Unique public DNS prefix for the deployment. The fqdn will look something like \'<dnsname>.westus.cloudapp.azure.com\'. Up to 62 chars, digits or dashes, lowercase, should start with a letter: must conform to \'^[a-z][a-z0-9-]{1,61}[a-z0-9]$\'.')
param dnsLabelPrefix string

@description('The name of the VM')
param vmName string

@description('The name of the administrator of the new VM. Exclusion list: \'admin\',\'administrator\'')
param adminUsername string

@description('The password for the administrator account of the new VM')
@secure()
param adminPassword string

@description('Public port number for RDP')
param rdpPort int = 50001

@description('Location for all resources.')
param location string = resourceGroup().location

@description('Size of the virtual machine')
param vmSize string = 'Standard_DS3_v2'

@description('VM Image publisher')
param imagePublisher string = 'MicrosoftWindowsDesktop'

@description('VM Image offer')
param imageOffer string = 'Windows-11'

@description('VM Image sku')
param imageSku string = 'win11-22h2-ent'

var storageAccountName = '${uniqueString(resourceGroup().id)}sardpvm'
var virtualNetworkName = 'rdpVNET'
var vnetAddressRange = '10.0.0.0/16'
var subnetAddressRange = '10.0.0.0/24'
var subnetName = 'Subnet'
var subnet_id = resourceId('Microsoft.Network/virtualNetworks/subnets', virtualNetworkName, subnetName)
var networkSecurityGroupName = 'Subnet-nsg'

resource publicIp 'Microsoft.Network/publicIPAddresses@2020-05-01' = {
  name: 'publicIp'
  location: location
  properties: {
    publicIPAllocationMethod: 'Dynamic'
    dnsSettings: {
      domainNameLabel: dnsLabelPrefix
    }
  }
}

resource storageAccount 'Microsoft.Storage/storageAccounts@2020-08-01-preview' = {
  name: storageAccountName
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
}

resource networkSecurityGroup 'Microsoft.Network/networkSecurityGroups@2019-08-01' = {
  name: networkSecurityGroupName
  location: location
  properties: {
    securityRules: [
      {
        name: 'default-allow-3389'
        properties: {
          priority: 1000
          access: 'Allow'
          direction: 'Inbound'
          destinationPortRange: '3389'
          protocol: 'Tcp'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
        }
      }
    ]
  }
}

resource virtualNetwork 'Microsoft.Network/virtualNetworks@2020-05-01' = {
  name: virtualNetworkName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        vnetAddressRange
      ]
    }
    subnets: [
      {
        name: 'Subnet'
        properties: {
          addressPrefix: subnetAddressRange
          networkSecurityGroup: {
            id: networkSecurityGroup.id
          }
        }
      }
    ]
  }
}

resource loadBalancer 'Microsoft.Network/loadBalancers@2020-05-01' = {
  name: 'loadBalancer'
  location: location
  properties: {
    frontendIPConfigurations: [
      {
        name: 'LBFE'
        properties: {
          publicIPAddress: {
            id: publicIp.id
          }
        }
      }
    ]
    backendAddressPools: [
      {
        name: 'LBBAP'
      }
    ]
    inboundNatRules: [
      {
        name: 'rdp'
        properties: {
          frontendIPConfiguration: {
            id: resourceId('Microsoft.Network/loadBalancers/frontendIPConfigurations', 'loadBalancer', 'LBFE')
          }
          protocol: 'Tcp'
          frontendPort: rdpPort
          backendPort: 3389
          enableFloatingIP: false
        }
      }
    ]
  }
}

resource vmName_nic 'Microsoft.Network/networkInterfaces@2020-05-01' = {
  name: '${vmName}-nic'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: subnet_id
          }
          loadBalancerBackendAddressPools: [
            {
              id: resourceId('Microsoft.Network/loadBalancers/backendAddressPools', 'loadBalancer', 'LBBAP')
            }
          ]
          loadBalancerInboundNatRules: [
            {
              id: resourceId('Microsoft.Network/loadBalancers/inboundNatRules', 'loadBalancer', 'rdp')
            }
          ]
        }
      }
    ]
  }
  dependsOn: [
    virtualNetwork
    loadBalancer
  ]
}

resource vm 'Microsoft.Compute/virtualMachines@2020-06-01' = {
  name: vmName
  location: location
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    osProfile: {
      computerName: vmName
      adminUsername: adminUsername
      adminPassword: adminPassword
    }
    storageProfile: {
      imageReference: {
        publisher: imagePublisher
        offer: imageOffer
        sku: imageSku
        version: 'latest'
      }
      osDisk: {
        createOption: 'FromImage'
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: vmName_nic.id
        }
      ]
    }
    diagnosticsProfile: {
      bootDiagnostics: {
        enabled: true
        storageUri: reference(storageAccountName, '2020-08-01-preview').primaryEndpoints.blob
      }
    }
  }
  dependsOn: [
    storageAccount

  ]
}
