# WireMock driven specs

Run:

```
./ec-specs sample/Provision.groovy

```

Gather traffic:

```
./startWiremock.sh
```
Set plugin property httpProxy to http://localhost:7887 and run procedures. Traffic will be gathered to EC-Parasoft/specs.
