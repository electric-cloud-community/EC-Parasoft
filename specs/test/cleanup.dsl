def plugin = getPlugin(pluginName: 'EC-Parasoft')
def pluginProject = plugin.projectName
def configPropertySheet = 'ec_plugin_cfgs'
def configName = 'specConfig'

deleteProperty(
    propertyName: "$configPropertySheet/$configName",
    projectName: pluginProject
)

deleteCredential(
    credentialName: configName,
    projectName: pluginProject
)


