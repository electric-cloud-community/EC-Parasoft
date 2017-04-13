@Grab(group='com.github.tomakehurst', module='wiremock-standalone', version='2.6.0')

import static com.github.tomakehurst.wiremock.core.WireMockConfiguration.wireMockConfig
import com.github.tomakehurst.wiremock.WireMockServer
import static com.github.tomakehurst.wiremock.client.WireMock.*




def config = wireMockConfig()
    .port(8089)
    .usingFilesUnderDirectory("/home/opc/plugins/EC-Parasoft/specs/")

WireMockServer wireMockServer = new WireMockServer(config);
wireMockServer.start();


