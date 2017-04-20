import java.io.File

def procName = 'Import Repository'
procedure procName, description: 'Imports the specified repository export file into the specified repository', {

    step 'import repository',
        command: '''
$[/myProject/scripts/preamble]
use EC::Parasoft;
EC::Parasoft->new->step_import_repository;
''',
        errorHandling: 'failProcedure',
        exclusiveMode: 'none',
        releaseMode: 'none',
        shell: 'ec-perl',
        timeLimitUnits: 'minutes'

}
