package org.eclipse.edc.gaiax.policy;

import java.time.Instant;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.concurrent.TimeUnit;

import org.eclipse.edc.iam.verifiablecredentials.spi.model.VerifiableCredential;
import org.eclipse.edc.spi.result.Result;

import okhttp3.MediaType;
import okhttp3.OkHttpClient;
import okhttp3.Request;
import okhttp3.RequestBody;

public class GaiaXCredentialValidator {
	public static final String LABEL_LEVEL_CLAIM = "gx:labelLevel";
	public static final String LABEL_CREDENTIAL_TYPE = "gx:LabelCredential";
	public static final String LEGAL_PERSON_TYPE = "gx:LegalPerson";
	public static final String COMPLIANT_CREDENTIALS_CLAIM = "gx:compliantCredentials";
	public static final String ISSUER_TYPE = "gx:Issuer";
	public static final String VAT_ID_TYPE = "gx:VatID";
	public static final String LEI_CODE_TYPE = "gx:LeiCode";
	public static final String EORI_TYPE = "gx:Eori";
	public static final String EUID_TYPE = "gx:Euid";

	private static final List<String> REQUIRED_COMPLIANT_TYPES = List.of(LEGAL_PERSON_TYPE, ISSUER_TYPE);
	private static final List<String> REGISTRATION_NUMBER_TYPES = List.of(VAT_ID_TYPE, LEI_CODE_TYPE, EORI_TYPE, EUID_TYPE);

	private static final MediaType VC_JWT = MediaType.parse("application/vc+jwt");

	private final String basicFunctionsUrl;
	private final OkHttpClient httpClient;

	public GaiaXCredentialValidator(String basicFunctionsUrl) {
		this.basicFunctionsUrl = basicFunctionsUrl;
		this.httpClient = new OkHttpClient.Builder()
				.connectTimeout(10, TimeUnit.SECONDS)
				.readTimeout(30, TimeUnit.SECONDS)
				.build();
	}

	public Result<Void> validateLabelLevel(VerifiableCredential vc, String requiredLevel) {
		if (vc.getCredentialSubject() == null || vc.getCredentialSubject().isEmpty()) {
			return Result.failure("Credential has no credentialSubject");
		}

		for (var subject : vc.getCredentialSubject()) {
			var level = subject.getClaims().get(LABEL_LEVEL_CLAIM);
			if (level instanceof String levelStr && levelStr.equalsIgnoreCase(requiredLevel)) {
				return Result.success();
			}
		}
		return Result.failure("Credential does not have required label level: " + requiredLevel);
	}

	public Result<Void> validateType(VerifiableCredential vc) {
		if (vc.getType() == null || vc.getType().stream().noneMatch(t -> t.contains(LABEL_CREDENTIAL_TYPE))) {
			return Result.failure("Credential type does not contain " + LABEL_CREDENTIAL_TYPE);
		}
		return Result.success();
	}

	public Result<Void> validateTime(VerifiableCredential vc) {
		var now = Instant.now();
		var validFrom = vc.getIssuanceDate();
		if (validFrom != null && now.isBefore(validFrom)) {
			return Result.failure("Credential not yet valid (validFrom : " + validFrom + ")");
		}
		var validUntil = vc.getExpirationDate();
		if (validUntil != null && now.isAfter(validUntil)) {
			return Result.failure("Credential expired (validUntil: " + validUntil + ")");
		}
		return Result.success();
	}

	public Result<Void> validateCompliantCredentials(VerifiableCredential vc) {
		if (vc.getCredentialSubject() == null || vc.getCredentialSubject().isEmpty()) {
			return Result.failure("Credential has no credentialSubject");
		}

		var presentTypes = new HashSet<String>();
		for (var subject : vc.getCredentialSubject()) {
			var compliant = subject.getClaims().get(COMPLIANT_CREDENTIALS_CLAIM);
			if (compliant instanceof List<?> list) {
				for (var entry : list) {
					if (entry instanceof Map<?, ?> entryMap) {
						var type = entryMap.get("type");
						if (type instanceof String typeStr) {
							presentTypes.add(typeStr);
						}
					}
				}
			}
		}
		var missing = REQUIRED_COMPLIANT_TYPES.stream()
				.filter(t -> !presentTypes.contains(t))
				.toList();

		if (!missing.isEmpty()) {
			return Result.failure("Credential is missing required compliant credentials: " + missing);
		}

		var hasRegistration = REGISTRATION_NUMBER_TYPES.stream().anyMatch(presentTypes::contains);
		if (!hasRegistration) {
			return Result.failure("Credential is missing a registration number credential (one of "
					+ REGISTRATION_NUMBER_TYPES + ")");
		}
		return Result.success();
	}

	public Result<Void> validateViaBasicFunctions(String rawJwt) {
		try {
			var url = basicFunctionsUrl.replaceAll("/$", "") + "/api/jwt/compliance-verification";
			var request = new Request.Builder()
					.url(url)
					.addHeader("Accept", "application/json")
					.post(RequestBody.create(rawJwt, VC_JWT))
					.build();
			var response = httpClient.newCall(request).execute();
			var body = response.body() != null ? response.body().string().trim() : "";

			if (!response.isSuccessful()) {
				return Result.failure("Gaia-X Basic Functions request failed: %d %s".formatted(response.code(), body));
			}

			if (body.contains("\"valid\":true")) {
				return Result.success();
			}
			return Result.failure("Gaia-X Basic Functions validation returned: " + body);
		} catch (Exception e) {
			return Result.failure("Gaia-X Basic Functions call error: " + e.getMessage());
		}
	}

	public Result<Void> validate(VerifiableCredential vc, String rawJwt) {
		var typeResult = validateType(vc);
		if (typeResult.failed()) {
			return typeResult;
		}

		var timeResult = validateTime(vc);
		if (timeResult.failed()) {
			return timeResult;
		}

		var compliantResult = validateCompliantCredentials(vc);
		if (compliantResult.failed()) {
			return compliantResult;
		}

		if (basicFunctionsUrl != null && !basicFunctionsUrl.isBlank() && rawJwt != null) {
			var remoteResult = validateViaBasicFunctions(rawJwt);
			if (remoteResult.failed()) {
				return remoteResult;
			}
		}

		return Result.success();
	}
}
