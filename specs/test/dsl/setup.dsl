def configPropertySheet = 'ec_plugin_cfgs'
def configName = 'specConfig'
def plugin = getPlugin(pluginName: 'EC-Parasoft')
def pluginProject = plugin.projectName
println pluginProject

def endpoint = 'http://localhost:8089/em/api'
def password = 'admin'
def username = 'admin'
def pluginName = 'EC-Parasoft'


setProperty(
    propertyName: "$configPropertySheet/$configName/endpoint",
    value: endpoint,
    projectName: pluginProject
)
setProperty(
    propertyName: "$configPropertySheet/$configName/credential",
    value: configName,
    projectName: pluginProject
)

createCredential(
    projectName: pluginProject,
    credentialName: configName,
    userName: username,
    password: password
)
attachCredential(
    projectName: pluginProject,
    credentialName: configName,
    procedureName: "Provision Environment",
    stepName: 'provision environment'
)



project "Parasoft spec", {
    procedure "Provision environment - good", {
        step 'provision', {
            subproject = "/plugins/$pluginName/project"
            subprocedure = "Provision Environment"

            actualParameter 'config', configName
            actualParameter 'systemName', 'Parabank'
            actualParameter 'environmentName', 'Golden'
            actualParameter 'environmentInstanceName', 'negative'
        }
    }
}
