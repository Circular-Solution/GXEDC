package org.eclipse.edc.gaiax.issuer.s3;

import org.eclipse.edc.gaiax.issuer.spi.VcPublisher;
import org.eclipse.edc.runtime.metamodel.annotation.Extension;
import org.eclipse.edc.runtime.metamodel.annotation.Provider;
import org.eclipse.edc.runtime.metamodel.annotation.Setting;
import org.eclipse.edc.spi.system.ServiceExtension;
import org.eclipse.edc.spi.system.ServiceExtensionContext;

@Extension(value = S3VcPublisherExtension.NAME)
public class S3VcPublisherExtension implements ServiceExtension {
	public static final String NAME = "Gaia-X GXDCH S3 VC Publisher";

	@Setting(description = "S3 bucket", key = "edc.gaiax.gxdch.s3.bucket")
	private String bucket;

	@Setting(description = "AWS region", key = "edc.gaiax.gxdch.s3.region", defaultValue = "ap-northeast-2")
	private String region;

	@Override
	public String name() {
		return NAME;
	}

	@Provider
	public VcPublisher vcPublisher(ServiceExtensionContext context) {
		var monitor = context.getMonitor().withPrefix("GXDCH-S3");
		return new S3VcPublisher(bucket, region, monitor);
	}

}
