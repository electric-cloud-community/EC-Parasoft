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
attachCredential(
    projectName: pluginProject,
    credentialName: configName,
    procedureName: "Get Endpoints",
    stepName: 'get endpoints'
)


project 'Parasoft spec', {
  resourceName = null
  workspaceName = null

  procedure 'Get Endpoints', {
    description = ''
    jobNameTemplate = ''
    resourceName = ''
    timeLimit = ''
    timeLimitUnits = 'minutes'
    workspaceName = ''

    step 'getEndpoints', {
      description = ''
      alwaysRun = '0'
      broadcast = '0'
      command = null
      condition = ''
      errorHandling = 'failProcedure'
      exclusiveMode = 'none'
      logFileName = null
      parallel = '0'
      postProcessor = null
      precondition = ''
      releaseMode = 'none'
      resourceName = ''
      shell = null
      subprocedure = 'Get Endpoints'
      subproject = '/plugins/EC-Parasoft/project'
      timeLimit = ''
      timeLimitUnits = 'minutes'
      workingDirectory = null
      workspaceName = ''
      actualParameter 'config', 'specConfig'
      actualParameter 'environmentName', 'Golden'
      actualParameter 'propertyName', ''
      actualParameter 'systemName', 'Parabank'
    }
  }

  procedure 'Provision environment - good', {
    jobNameTemplate = null
    resourceName = null
    timeLimitUnits = null
    workspaceName = null

    step 'provision', {
      alwaysRun = '0'
      broadcast = '0'
      command = null
      condition = null
      errorHandling = 'failProcedure'
      exclusiveMode = 'none'
      logFileName = null
      parallel = '0'
      postProcessor = null
      precondition = null
      releaseMode = 'none'
      resourceName = null
      shell = null
      subprocedure = 'Provision Environment'
      subproject = '/plugins/EC-Parasoft/project'
      timeLimitUnits = null
      workingDirectory = null
      workspaceName = null
      actualParameter 'config', 'specConfig'
      actualParameter 'environmentInstanceName', 'negative'
      actualParameter 'environmentName', 'Golden'
      actualParameter 'systemName', 'Parabank'
    }
  }

  procedure 'Provision environment - no such env', {
    description = ''
    jobNameTemplate = ''
    resourceName = ''
    timeLimit = ''
    timeLimitUnits = 'minutes'
    workspaceName = ''

    step 'provision', {
      description = ''
      alwaysRun = '0'
      broadcast = '0'
      command = null
      condition = ''
      errorHandling = 'failProcedure'
      exclusiveMode = 'none'
      logFileName = null
      parallel = '0'
      postProcessor = null
      precondition = ''
      releaseMode = 'none'
      resourceName = ''
      shell = null
      subprocedure = 'Provision Environment'
      subproject = '/plugins/EC-Parasoft/project'
      timeLimit = ''
      timeLimitUnits = 'minutes'
      workingDirectory = null
      workspaceName = ''
      actualParameter 'config', 'specConfig'
      actualParameter 'copyEnvironment', '0'
      actualParameter 'copyEnvServerName', ''
      actualParameter 'environmentCopyName', ''
      actualParameter 'environmentInstanceName', 'instance'
      actualParameter 'environmentName', 'no such env'
      actualParameter 'systemName', 'Parabank'
    }
  }
}
