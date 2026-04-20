package org.eclipse.edc.gaiax.issuer;

import org.eclipse.edc.gaiax.issuer.spi.VcPublisher;
import org.eclipse.edc.spi.result.Result;

public class NoopVcPublisher implements VcPublisher {

	@Override
	public Result<Void> publish(String vcUrl, String vcJwt) {
		return Result.success();
	}
}
