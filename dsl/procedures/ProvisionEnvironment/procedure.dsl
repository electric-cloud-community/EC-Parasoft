import java.io.File

def procName = 'Provision Environment'
procedure procName,
        description: 'Provisions the specified envionment with the specified instance', {

    step 'provision environment',
        command: '''
$[/myProject/scripts/preamble]
use EC::Parasoft;
EC::Parasoft->new->step_provision_environment;
''',
        errorHandling: 'failProcedure',
        exclusiveMode: 'none',
        releaseMode: 'none',
        shell: 'ec-perl',
        timeLimitUnits: 'minutes'

}
