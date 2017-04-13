// @Grab(group='com.github.tomakehurst', module='wiremock-standalone', version='2.6.0')
import spock.lang.*
import com.electriccloud.spec.SpockTestSupport

import static com.github.tomakehurst.wiremock.core.WireMockConfiguration.wireMockConfig
import com.github.tomakehurst.wiremock.WireMockServer
import static com.github.tomakehurst.wiremock.client.WireMock.*
import com.electriccloud.Test


/**
 * Test example that needs to wait for
 * processing  to happen on the
 * ElectricFlow server.
 */
class ProvisionProcedureTestSpec extends SpockTestSupport {

	def config = wireMockConfig().port(8089).usingFilesUnderDirectory("/home/opc/plugins/EC-Parasoft/specs/")
	WireMockServer wireMockServer = new WireMockServer(config);
	// wireMockServer.start();
	def pluginName = 'EC-Parasoft-1.0.0'
	def configName = 'specsConfig'
	def endpoint = 'http://localhost:8089/em/api'
	def username = 'admin'
	def password = 'admin'
	def configPropertySheet = 'ec_plugin_cfgs'


	def "run provision"() {

        given: 'provision procedure'
			wireMockServer.start()
            def test = new Test()
            test.method()
			dsl """
				setProperty(
					propertyName: '$configPropertySheet/$configName/endpoint',
					value: '$endpoint',
					projectName: '$pluginName'
				)
				setProperty(
					propertyName: '$configPropertySheet/$configName/credential',
					value: '$configName',
					projectName: '$pluginName'
				)
				createCredential(
					projectName: '$pluginName',
					credentialName: "$configName",
					userName: '$username',
					password: '$password'
				)

			    attachCredential(
			        projectName: '$pluginName',
			        credentialName: '$configName',
			        procedureName: "Provision Environment",
			        stepName: 'provision environment'
			    )
			"""


        when: 'the procedure is run'
			def result = dsl '''
				runProcedure(
					projectName: 'EC-Parasoft-1.0.0',
					procedureName: 'Provision Environment',
					actualParameter: [
					  config: 'specsConfig',
					  systemName: 'Parabank',
					  environmentName: 'Golden',
					  environmentInstanceName: 'negative'
					]
				)
			'''

        then:
			assert result?.jobId

			waitUntil {
                jobSucceeded result.jobId
			}
            println "Job is completed"

        cleanup:
        	wireMockServer.stop()
        	dsl """
        		deleteProperty(
        			propertyName: '$configPropertySheet/$configName',
        			projectName: '$pluginName'
        		)

        		deleteCredential(
        			credentialName: '$configName',
        			projectName: '$pluginName'
        		)
        	"""
			// dsl "deleteProject 'Hello Project'"

    }
}
