import java.io.File

def procName = 'Update Data Set'
procedure procName, description: 'Updates the specified dataset', {

    step 'update data set',
        command: '''
$[/myProject/scripts/preamble]
use EC::Parasoft;
EC::Parasoft->new->step_update_dataset;
''',
        errorHandling: 'failProcedure',
        exclusiveMode: 'none',
        releaseMode: 'none',
        shell: 'ec-perl',
        timeLimitUnits: 'minutes'

}
