import java.io.File

def procName = 'Execute Job'
procedure procName,
        description: 'Executes the specified SOA test job', {

    step 'execute job',
        command: '''
$[/myProject/scripts/preamble]
use EC::Parasoft;
EC::Parasoft->new->step_execute_job;
''',
        errorHandling: 'failProcedure',
        exclusiveMode: 'none',
        releaseMode: 'none',
        shell: 'ec-perl',
        timeLimitUnits: 'minutes'

}
