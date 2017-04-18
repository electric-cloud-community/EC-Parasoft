import java.io.File

def procName = 'Delete Environment'
procedure procName, description: 'Deletes the specified environment', {

    step 'delete environment',
        command: '''
$[/myProject/scripts/preamble]
use EC::Parasoft;
EC::Parasoft->new->step_delete_environment;
''',
        errorHandling: 'failProcedure',
        exclusiveMode: 'none',
        releaseMode: 'none',
        shell: 'ec-perl',
        timeLimitUnits: 'minutes'

}
