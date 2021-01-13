// Global Data
param environmentName string {
  allowed: [
    'prod'
    'dev'
  ]
}
var defaultLocation = resourceGroup().location

// Storage Account data
param storageAccountName string {
    minLength: 3
    maxLength: 24

}
var sku = environmentName == 'prod' ? 'Standard_GRS' : 'Standard_LRS'

resource diagsAccount 'Microsoft.Storage/storageAccounts@2019-06-01' = {
    name: storageAccountName
    location: defaultLocation
    sku: {
      name: sku
    }
    kind: 'Storage'
  }


// Vm Related Data
param numberOfVM int {
    minValue: 1
    maxValue: 3
}
var diskSku = environmentName == 'prod' ? 'Premium_LRS' : 'Standard_LRS'
param vmSku string {
    allowed: [
        'Standard_F2s'
        'Standard_B2ms'
      ] 
}
param vmOS string {
    default: '2019-Datacenter'
    allowed: [
        'windows-ente'
        '2016-Datacenter'
        '2016-Datacenter-Server-Core'
        '2016-Datacenter-Server-Core-smalldisk'
        '2019-Datacenter'
        '2019-Datacenter-Server-Core'
        '2019-Datacenter-Server-Core-smalldisk'
      ] 
}
param localAdminPassword string {
    secure: true
    metadata: {
        description: 'password for the windows VM'
    }
}
param vmPrefix string {
    minLength: 1
    maxLength: 9
}
var defaultVmName = '${vmPrefix}-${environmentName}'
var defaultVmNicName = '${defaultVmName}-nic'

resource vmNic 'Microsoft.Network/networkInterfaces@2020-06-01' = {
    name: defaultVmNicName
    location: defaultLocation
    properties: {
      ipConfigurations: [
        {
          name: 'ipconfig1'
          properties: {
            subnet: {
              id: '${vnet.id}/subnets/front'
            }
            privateIPAllocationMethod: 'Dynamic'
          }
        }
      ]
    }
  }

  resource vmDataDisk 'Microsoft.Compute/disks@2020-06-30' = {
    name: '${defaultVmName}-vhd'
    location: defaultLocation
    sku: {
        name: 'Premium_LRS'
    }
    properties: {
        diskSizeGB: 32
        creationData: {
            createOption: 'Empty'
        }
    }

  }

  resource vm 'Microsoft.Compute/virtualMachines@2020-06-01' = {
    name: defaultVmName
    location: defaultLocation
    properties: {
      osProfile: {
        computerName: defaultVmName
        adminUsername: 'localadm'
        adminPassword: localAdminPassword
        windowsConfiguration: {
          //provisionVMAgent: true
        }
      }
      hardwareProfile: {
        vmSize: 'Standard_F2s'
      }
      storageProfile: {
        imageReference: {
          publisher: 'MicrosoftWindowsServer'
          offer: 'WindowsServer'
          sku: vmOS
          version: 'latest'
        }
        osDisk: {
          createOption: 'FromImage'
        }
        dataDisks: [
          {
            name: '${defaultVmName}-vhd'
            createOption: 'Attach'
            caching: 'ReadOnly'
            lun: 0
            managedDisk: {
              id: vmDataDisk.id
            }
          }
        ]
      }
      networkProfile: {
        networkInterfaces: [
          {
            properties: {
              primary: true
            }
            id: vmNic.id
          }
        ]
      }
      diagnosticsProfile: {
        bootDiagnostics: {
          enabled: true
          storageUri: diagsAccount.properties.primaryEndpoints.blob
        }
      }
    }
  }

//Network related data
param vnetName string {
    metadata: {
        description: 'name of the Virtual network'
    }
}
var vnetConfig = {
    vnetprefix: '10.0.0.0/21'
    subnet: {
            name: 'front'
            addressPrefix: '10.0.0.0/24'
        }
} 


  resource vnet 'Microsoft.Network/virtualNetworks@2020-05-01' = {
    name: vnetName
    location: defaultLocation
    properties: {
      addressSpace: {
        addressPrefixes: [
          vnetConfig.vnetprefix
        ]
      }
      subnets: [ 
        {
          name: vnetConfig.subnet.name
          properties: {
            addressPrefix: vnetConfig.subnet.addressPrefix
          }
        }

      ]
    }
  }