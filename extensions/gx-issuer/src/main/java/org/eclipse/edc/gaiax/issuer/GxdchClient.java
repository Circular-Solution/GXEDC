package org.eclipse.edc.gaiax.issuer;

import java.util.concurrent.TimeUnit;

import org.eclipse.edc.spi.monitor.Monitor;
import org.eclipse.edc.spi.result.Result;

import okhttp3.HttpUrl;
import okhttp3.MediaType;
import okhttp3.OkHttpClient;
import okhttp3.Request;
import okhttp3.RequestBody;

public class GxdchClient {
	private static final MediaType VP_JWT = MediaType.parse("application/vp+jwt");

	private final String notaryUrl;
	private final String complianceUrl;
	private final OkHttpClient httpClient;
	private final Monitor monitor;

	public GxdchClient(String notaryUrl, String complianceUrl, Monitor monitor) {
		this.notaryUrl = notaryUrl;
		this.complianceUrl = complianceUrl;
		this.monitor = monitor;
		this.httpClient = new OkHttpClient.Builder()
				.connectTimeout(15, TimeUnit.SECONDS)
				.readTimeout(60, TimeUnit.SECONDS)
				.build();
	}

	private String stripQuotes(String s) {
		return s.trim().replaceAll("^\"|\"$", "");
	}

	private Result<String> getRegistrationCredential(String type, String value, String vcId, String subjectId) {
		try {
			var base = HttpUrl.parse(notaryUrl.replaceAll("/$", "") + "/registration-numbers/" + type + "/" + value);
			if (base == null) {
				return Result.failure("Invalid notary URL: " + notaryUrl);
			}
			var url = base.newBuilder()
					.addQueryParameter("vcId", vcId)
					.addQueryParameter("subjectId", subjectId)
					.build();
			var request = new Request.Builder()
					.url(url)
					.addHeader("Accept", "application/vc+jwt")
					.get()
					.build();

			monitor.info("GXDCH notary request: %s".formatted(url));

			var response = httpClient.newCall(request).execute();
			var body = response.body() != null ? response.body().string() : "";

			if (!response.isSuccessful()) {
				return Result.failure("GXDCH notary request failed: %d %s".formatted(response.code(), body));
			}
			return Result.success(stripQuotes(body));
		} catch (Exception e) {
			return Result.failure("GXDCH notary call error: " + e.getMessage());
		}
	}

	public Result<String> requestComplianceCredential(String vpJwt, String vcId, String level) {
		try {
			var base = HttpUrl.parse(complianceUrl.replaceAll("/$", "") + "/api/credential-offers/" + level);
			if (base == null) {
				return Result.failure("Invalid compliance URL: " + complianceUrl);
			}
			var url = base.newBuilder().addQueryParameter("vcid", vcId).build();

			var request = new Request.Builder()
					.url(url)
					.addHeader("Content-Type", "application/vp+jwt")
					.post(RequestBody.create(vpJwt, VP_JWT))
					.build();

			monitor.info("GXDCH compliance request: %s".formatted(url));

			var response = httpClient.newCall(request).execute();
			var body = response.body() != null ? response.body().string() : "";

			if (!response.isSuccessful()) {
				return Result.failure("GXDCH compliance request failed: %d %s".formatted(response.code(), body));
			}
			return Result.success(stripQuotes(body));
		} catch (Exception e) {
			return Result.failure("GXDCH compliance call error: " + e.getMessage());
		}
	}

	public Result<String> requestLeiCodeCredential(String leiCode, String vcId, String subjectId) {
		return getRegistrationCredential("lei-code", leiCode, vcId, subjectId);
	}

	public Result<String> requestVatIdCredential(String vatId, String vcId, String subjectId) {
		return getRegistrationCredential("vat-id", vatId, vcId, subjectId);
	}

	public Result<String> requestEoriCredential(String eori, String vcId, String subjectId) {
		return getRegistrationCredential("eori", eori, vcId, subjectId);
	}

	public Result<String> requestEuidCredential(String euid, String vcId, String subjectId) {
		return getRegistrationCredential("euid", euid, vcId, subjectId);
	}
}
