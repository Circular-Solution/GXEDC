package com.circularsolution.edc.dataplane.publicapi;

import jakarta.ws.rs.DELETE;
import jakarta.ws.rs.GET;
import jakarta.ws.rs.HEAD;
import jakarta.ws.rs.PATCH;
import jakarta.ws.rs.POST;
import jakarta.ws.rs.PUT;
import jakarta.ws.rs.Path;
import jakarta.ws.rs.Produces;
import jakarta.ws.rs.container.AsyncResponse;
import jakarta.ws.rs.container.ContainerRequestContext;
import jakarta.ws.rs.container.Suspended;
import jakarta.ws.rs.core.Context;
import jakarta.ws.rs.core.HttpHeaders;
import jakarta.ws.rs.core.MediaType;
import jakarta.ws.rs.core.Response;
import jakarta.ws.rs.core.StreamingOutput;
import org.eclipse.edc.connector.dataplane.spi.iam.DataPlaneAuthorizationService;
import org.eclipse.edc.connector.dataplane.spi.pipeline.PipelineService;
import org.eclipse.edc.connector.dataplane.util.sink.AsyncStreamingDataSink;
import org.eclipse.edc.spi.types.domain.DataAddress;
import org.eclipse.edc.spi.types.domain.transfer.DataFlowStartMessage;
import org.eclipse.edc.spi.types.domain.transfer.FlowType;

import java.io.BufferedReader;
import java.io.IOException;
import java.io.InputStreamReader;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;
import java.util.concurrent.ExecutorService;
import java.util.stream.Collectors;

import static jakarta.ws.rs.core.MediaType.APPLICATION_JSON;
import static jakarta.ws.rs.core.MediaType.WILDCARD;
import static jakarta.ws.rs.core.Response.Status.FORBIDDEN;
import static jakarta.ws.rs.core.Response.Status.INTERNAL_SERVER_ERROR;
import static jakarta.ws.rs.core.Response.Status.UNAUTHORIZED;
import static jakarta.ws.rs.core.Response.status;
import static org.eclipse.edc.connector.dataplane.spi.schema.DataFlowRequestSchema.BODY;
import static org.eclipse.edc.connector.dataplane.spi.schema.DataFlowRequestSchema.MEDIA_TYPE;
import static org.eclipse.edc.connector.dataplane.spi.schema.DataFlowRequestSchema.METHOD;
import static org.eclipse.edc.connector.dataplane.spi.schema.DataFlowRequestSchema.PATH;
import static org.eclipse.edc.connector.dataplane.spi.schema.DataFlowRequestSchema.QUERY_PARAMS;

@Path("{any:.*}")
@Produces(WILDCARD)
public class DataPlanePublicApiController {

  private final PipelineService pipelineService;
  private final ExecutorService executorService;
  private final DataPlaneAuthorizationService authorizationService;

  public DataPlanePublicApiController(PipelineService pipelineService,
                                      ExecutorService executorService,
                                      DataPlaneAuthorizationService authorizationService) {
    this.pipelineService = pipelineService;
    this.executorService = executorService;
    this.authorizationService = authorizationService;
  }

  @GET
  public void get(@Context ContainerRequestContext requestContext, @Suspended AsyncResponse response) {
    handle(requestContext, response);
  }

  @HEAD
  public void head(@Context ContainerRequestContext requestContext, @Suspended AsyncResponse response) {
    handle(requestContext, response);
  }

  @POST
  public void post(@Context ContainerRequestContext requestContext, @Suspended AsyncResponse response) {
    handle(requestContext, response);
  }

  @PUT
  public void put(@Context ContainerRequestContext requestContext, @Suspended AsyncResponse response) {
    handle(requestContext, response);
  }

  @DELETE
  public void delete(@Context ContainerRequestContext requestContext, @Suspended AsyncResponse response) {
    handle(requestContext, response);
  }

  @PATCH
  public void patch(@Context ContainerRequestContext requestContext, @Suspended AsyncResponse response) {
    handle(requestContext, response);
  }

  private void handle(ContainerRequestContext requestContext, AsyncResponse response) {
    var token = requestContext.getHeaders().getFirst(HttpHeaders.AUTHORIZATION);
    if (token == null) {
      response.resume(error(UNAUTHORIZED, List.of("Missing Authorization Header")));
      return;
    }

    var requestData = buildRequestData(requestContext);
    var sourceDataAddress = authorizationService.authorize(token, requestData);
    if (sourceDataAddress.failed()) {
      response.resume(error(FORBIDDEN, sourceDataAddress.getFailureMessages()));
      return;
    }

    var startMessage = createDataFlowStartMessage(requestContext, sourceDataAddress.getContent());
    processRequest(startMessage, response);
  }

  private Map<String, Object> buildRequestData(ContainerRequestContext requestContext) {
    var requestData = new HashMap<String, Object>();
    requestData.put("headers", requestContext.getHeaders());
    requestData.put("path", requestContext.getUriInfo());
    requestData.put("method", requestContext.getMethod());
    requestData.put("content-type", requestContext.getMediaType());
    return requestData;
  }

  private DataFlowStartMessage createDataFlowStartMessage(ContainerRequestContext requestContext,
                                                           DataAddress sourceDataAddress) {
    var props = new HashMap<String, String>();
    props.put(METHOD, requestContext.getMethod());
    props.put(QUERY_PARAMS, requestContext.getUriInfo().getQueryParameters().entrySet()
      .stream()
      .flatMap(e -> e.getValue().stream().map(v -> e.getKey() + "=" + v))
      .collect(Collectors.joining("&")));

    var pathInfo = requestContext.getUriInfo().getPath();
    props.put(PATH, pathInfo.startsWith("/") ? pathInfo.substring(1) : pathInfo);

    Optional.ofNullable(requestContext.getMediaType())
      .map(MediaType::toString)
      .ifPresent(mediaType -> {
        props.put(MEDIA_TYPE, mediaType);
        try (var br = new BufferedReader(new InputStreamReader(requestContext.getEntityStream()))) {
          props.put(BODY, br.lines().collect(Collectors.joining("\n")));
        } catch (IOException e) {
          throw new RuntimeException("Failed to read request body", e);
        }
      });

    return DataFlowStartMessage.Builder.newInstance()
      .processId(UUID.randomUUID().toString())
      .sourceDataAddress(sourceDataAddress)
      .flowType(FlowType.PULL)
      .destinationDataAddress(DataAddress.Builder.newInstance()
        .type(AsyncStreamingDataSink.TYPE)
        .build())
      .id(UUID.randomUUID().toString())
      .properties(props)
      .build();
  }

  private void processRequest(DataFlowStartMessage startMessage, AsyncResponse response) {
    AsyncStreamingDataSink.AsyncResponseContext asyncResponseContext = callback -> {
      StreamingOutput output = t -> callback.outputStreamConsumer().accept(t);
      var resp = Response.ok(output).type(callback.mediaType()).build();
      return response.resume(resp);
    };

    var sink = new AsyncStreamingDataSink(asyncResponseContext, executorService);

    pipelineService.transfer(startMessage, sink)
      .whenComplete((result, throwable) -> {
        if (throwable == null) {
          if (result.failed()) {
            response.resume(error(INTERNAL_SERVER_ERROR, result.getFailureMessages()));
          }
        } else {
          response.resume(error(INTERNAL_SERVER_ERROR,
            List.of("Unhandled exception during data transfer: " + throwable.getMessage())));
        }
      });
  }

  private static Response error(Response.Status httpStatus, List<String> errors) {
    return status(httpStatus).type(APPLICATION_JSON).entity(Map.of("errors", errors)).build();
  }
}
