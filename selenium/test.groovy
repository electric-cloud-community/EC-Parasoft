@Grapes([
    @GrabExclude(group = 'org.codehaus.groovy', module='groovy-all'), // Or 'commons-logging:commons-logging'
    @Grab("org.gebish:geb-core:1.1.1"),
    @Grab("org.seleniumhq.selenium:selenium-firefox-driver:2.52.0"),
    @Grab("org.seleniumhq.selenium:selenium-support:2.52.0"),
    @Grab(group='org.seleniumhq.selenium', module='selenium-htmlunit-driver', version='2.52.0')

])

import org.openqa.selenium.htmlunit.HtmlUnitDriver
import geb.Browser

def driver = { new HtmlUnitDriver() }

def browser = new Browser(driver: new HtmlUnitDriver())

def url = args[0]
browser.go(url)
def carousel = browser.$("div.carousel-inner")

assert carousel
assert browser.$("h1.model-title", 1).displayed
assert browser.$("h1.model-title", 1).text() == "Kawasaki Vulcan"
def table = browser.$("table.table", 1).find("td")
def data = table.collect {
    it.text()
}

assert data == ['Model', 'Vulcan Vaquero', 'Year', '2013', 'Asking Price', '$10750',
'Mileage', '2085 miles', 'Engine type', 'SOHC V-Twin', 'Displacement',
'1700cc', 'Transmission Speed', '6', 'Final Drive',
'Belt', 'Fuel Capacity', '5.3 gal.', 'Curb weigth', '845 lb']

assert browser.$(".right.carousel-control").click()

browser.$("table.table>td").each {
    println it
}
