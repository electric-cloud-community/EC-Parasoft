import java.io.File

def procName = 'Get Endpoints'
procedure procName, description: 'Gets endpoints of the provisioned environment', {

    step 'get endpoints',
        command: '''
$[/myProject/scripts/preamble]
use EC::Parasoft;
EC::Parasoft->new->step_get_endpoints;
''',
        errorHandling: 'failProcedure',
        exclusiveMode: 'none',
        releaseMode: 'none',
        shell: 'ec-perl',
        timeLimitUnits: 'minutes'

}
