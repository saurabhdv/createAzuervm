// input params START
param location string = 'Sweden'
param subnetId string = 'your_subnetId'
param tag_department string = 'QA'
param tag_sla string = 'Standard'
param tag_systemOwner string = ''
param tag_team string = 'QA'
param vmName string
param adminUsername string = 'qa'
@description('Password for the VM, it must follow the MS password rules')
@secure()
param adminPassword string
//Get the current date for the created tag
param tag_date string = utcNow('ddMMyy')
param autoShutdown_Status string = 'enabled'
param autoShutdown_Time string = '19:00'
param autoShutdown_Time_Zone string = 'UTC'


//Build all the tags as an object to use in all the elements
param tags object = {
  department: tag_department
  sla: tag_sla
  systemOwner: tag_systemOwner
  team: tag_team
  created: tag_date
}


resource pip 'Microsoft.Network/publicIPAddresses@2023-09-01' = {
  name: vmName  
  location: location
  tags: tags
  sku: {
    name: 'Standard'
    tier: 'Regional'
  }
  properties: {
    deleteOption: 'Delete'
    publicIPAddressVersion: 'IPv4'
    publicIPAllocationMethod: 'Static'
    idleTimeoutInMinutes: 4
    ipTags: []
  }
}



resource nic 'Microsoft.Network/networkInterfaces@2023-09-01' = {
  name: vmName
  location: location
  tags: tags
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          publicIPAddress: {
            id: pip.id
            properties: {
              deleteOption: 'Delete'
            }
          }
          subnet: {
            id: subnetId
          }
          primary: true
          privateIPAddressVersion: 'IPv4'
          
        }
      }
    ]
  }
}


resource linuxvm 'Microsoft.Compute/virtualMachines@2023-07-01' = {
  name: vmName  
  location: location
  tags: tags
  properties: {
    hardwareProfile: {
      vmSize: 'Standard_D2as_v4'
    }
    additionalCapabilities: {
      hibernationEnabled: false
    }
    osProfile: {
      computerName: vmName
      adminUsername: adminUsername
      adminPassword: adminPassword
    }
    storageProfile: {
      imageReference: {
        publisher: 'canonical'
        offer: '0001-com-ubuntu-server-jammy'
        sku: '22_04-lts-gen2'
        version: 'latest'
      }
      osDisk: {
        createOption: 'FromImage'
        diskSizeGB: 30

        managedDisk: {
          storageAccountType: 'Standard_LRS'
        }
        deleteOption: 'Delete'
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: nic.id
          properties:{
            deleteOption: 'Delete'
          }
        }
      ]

    }
    diagnosticsProfile: {
      bootDiagnostics: {
        enabled: true
      }
    }
    
    securityProfile: {
      uefiSettings: {
          secureBootEnabled: true
          vTpmEnabled: true
      }
      securityType: 'TrustedLaunch'
  }

}
}

resource shutdown_computevm_windows 'Microsoft.DevTestLab/schedules@2018-09-15' = {
  name: 'shutdown-computevm-${vmName}'  
  location: location
  properties: {
    status: autoShutdown_Status
    taskType: 'ComputeVmShutdownTask'
    dailyRecurrence: {
      time: autoShutdown_Time
    }
    timeZoneId: autoShutdown_Time_Zone
    targetResourceId: linuxvm.id

  }
}
