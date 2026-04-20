package org.eclipse.edc.gaiax.issuer.s3;

import java.net.URI;

import org.eclipse.edc.gaiax.issuer.spi.VcPublisher;
import org.eclipse.edc.spi.monitor.Monitor;
import org.eclipse.edc.spi.result.Result;

import software.amazon.awssdk.auth.credentials.DefaultCredentialsProvider;
import software.amazon.awssdk.core.sync.RequestBody;
import software.amazon.awssdk.regions.Region;
import software.amazon.awssdk.services.s3.S3Client;
import software.amazon.awssdk.services.s3.model.PutObjectRequest;

public class S3VcPublisher implements VcPublisher {
	private final S3Client client;
	private final String bucket;
	private final Monitor monitor;

	public S3VcPublisher(String bucket, String region, Monitor monitor) {
		this.bucket = bucket;
		this.monitor = monitor;
		this.client = S3Client.builder()
				.region(Region.of(region))
				.credentialsProvider(DefaultCredentialsProvider.create())
				.build();
	}

	@Override
	public Result<Void> publish(String vcUrl, String vcJwt) {
		try {
			var key = URI.create(vcUrl).getPath().replaceAll("^/", "");
			var req = PutObjectRequest.builder()
					.bucket(bucket)
					.key(key)
					.contentType("application/json")
					.build();
			client.putObject(req, RequestBody.fromString(vcJwt));
			monitor.info("Uploaded VC to s3://%s/%s".formatted(bucket, key));
			return Result.success();
		} catch (Exception e) {
			return Result.failure("S3 upload failed: " + e.getMessage());
		}
	}

}
