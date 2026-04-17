package com.circularsolution.edc.dataplane.publicapi;

import org.eclipse.edc.connector.dataplane.spi.Endpoint;
import org.eclipse.edc.connector.dataplane.spi.iam.DataPlaneAuthorizationService;
import org.eclipse.edc.connector.dataplane.spi.iam.PublicEndpointGeneratorService;
import org.eclipse.edc.connector.dataplane.spi.pipeline.PipelineService;
import org.eclipse.edc.runtime.metamodel.annotation.Extension;
import org.eclipse.edc.runtime.metamodel.annotation.Inject;
import org.eclipse.edc.runtime.metamodel.annotation.Setting;
import org.eclipse.edc.spi.system.ExecutorInstrumentation;
import org.eclipse.edc.spi.system.ServiceExtension;
import org.eclipse.edc.spi.system.ServiceExtensionContext;
import org.eclipse.edc.web.spi.WebService;

import org.eclipse.edc.web.spi.configuration.PortMapping;
import org.eclipse.edc.web.spi.configuration.PortMappingRegistry;

import java.util.concurrent.Executors;

@Extension(value = DataPlanePublicApiExtension.NAME)
public class DataPlanePublicApiExtension implements ServiceExtension {

  public static final String NAME = "Data Plane Public API";

  private static final int DEFAULT_PUBLIC_PORT = 11002;
  private static final String DEFAULT_PUBLIC_PATH = "/api/public";
  private static final int DEFAULT_THREAD_POOL = 10;

  @Setting(
    description = "Base URL of the public API endpoint",
    key = "edc.dataplane.api.public.baseurl",
    required = true
  )
  private String publicBaseUrl;

  @Setting(
    key = "web.http.public.port",
    description = "Port for public api context",
    defaultValue = DEFAULT_PUBLIC_PORT + "",
    required = false
  )
  private int publicPort;

  @Setting(
    key = "web.http.public.path",
    description = "Path for public api context",
    defaultValue = DEFAULT_PUBLIC_PATH,
    required = false
  )
  private String publicPath;

  @Inject
  private PublicEndpointGeneratorService generatorService;

  @Inject
  private PortMappingRegistry portMappingRegistry;

  @Inject
  private WebService webService;

  @Inject
  private PipelineService pipelineService;

  @Inject
  private ExecutorInstrumentation executorInstrumentation;

  @Inject
  private DataPlaneAuthorizationService authorizationService;

  @Override
  public String name() {
    return NAME;
  }

  @Override
  public void initialize(ServiceExtensionContext context) {
    var portMapping = new PortMapping("public", publicPort, publicPath);
    portMappingRegistry.register(portMapping);

    var endpoint = Endpoint.url(publicBaseUrl);
    generatorService.addGeneratorFunction("HttpData", dataAddress -> endpoint);

    var executorService = executorInstrumentation.instrument(
      Executors.newFixedThreadPool(DEFAULT_THREAD_POOL),
      "Data plane public API transfers"
    );

    var controller = new DataPlanePublicApiController(
      pipelineService, executorService, authorizationService
    );
    webService.registerResource("public", controller);

    context.getMonitor().info("Registered HttpData public API at %s (port %d, path %s)"
      .formatted(publicBaseUrl, publicPort, publicPath));
  }
}
