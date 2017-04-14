// @Grab(group='com.github.tomakehurst', module='wiremock-standalone', version='2.6.0')
import spock.lang.*
import com.electriccloud.spec.SpockTestSupport

import static com.github.tomakehurst.wiremock.core.WireMockConfiguration.wireMockConfig
import com.github.tomakehurst.wiremock.WireMockServer
import static com.github.tomakehurst.wiremock.client.WireMock.*


/**
 * Test example that needs to wait for
 * processing  to happen on the
 * ElectricFlow server.
 */
class ProvisionProcedureTestSpec extends SpockTestSupport {


	def pluginName = 'EC-Parasoft'
    String pluginProject = getPluginProject('EC-Parasoft')
	def configName = 'specsConfig'
	def endpoint = 'http://localhost:8089/em/api'
	def username = 'admin'
	def password = 'admin'
	def configPropertySheet = 'ec_plugin_cfgs'
    def wireMockServer


    @Override
    def doSetupSpec() {
        def uri = this.class.getClassLoader().getResource("wiremock").toURI()
        File wiremockFile = new File(uri)
        def wiremockDir = wiremockFile.toString()
        println wiremockDir
        assert wiremockDir
        def config = wireMockConfig().port(8089).usingFilesUnderDirectory(wiremockDir)
        wireMockServer = new WireMockServer(config);
        wireMockServer.start();
    }

    @Override
    def doCleanupSpec() {
        wireMockServer.stop()
    }

	def "run provision"() {
        given: 'provision procedure'
            dslFile 'dsl/cleanup.dsl'
            dslFile "dsl/setup.dsl"


        when: 'the procedure is run'
			def result = dsl """
				runProcedure(
					projectName: 'Parasoft spec',
					procedureName: 'Provision environment - good'
				)
			"""
        then:
			assert result?.jobId

			waitUntil {
                jobCompleted result.jobId
			}
            println "Job is completed"

            assert jobStep(result.jobId, 'provision environment').outcome == 'success'

        cleanup:

            dslFile 'dsl/cleanup.dsl'

    }

    def getPluginProject(String plugin) {
        def response = dsl """
            getPlugin(pluginName: '$plugin')
        """
        def projectName = response?.plugin?.projectName
        assert projectName
        projectName
    }
}
