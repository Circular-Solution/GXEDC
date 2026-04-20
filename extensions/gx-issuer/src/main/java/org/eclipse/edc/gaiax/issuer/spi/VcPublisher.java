package org.eclipse.edc.gaiax.issuer.spi;

import org.eclipse.edc.spi.result.Result;

@FunctionalInterface
public interface VcPublisher {
	Result<Void> publish(String vcUrl, String vcJwt);
}
