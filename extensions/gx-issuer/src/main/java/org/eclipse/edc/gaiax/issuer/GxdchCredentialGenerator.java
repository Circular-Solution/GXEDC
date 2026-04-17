package org.eclipse.edc.gaiax.issuer;

import java.time.Instant;
import java.util.Date;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;

import com.nimbusds.jose.JOSEObjectType;
import com.nimbusds.jose.JWSAlgorithm;
import com.nimbusds.jose.JWSHeader;
import com.nimbusds.jose.crypto.RSASSASigner;
import com.nimbusds.jose.jwk.RSAKey;
import com.nimbusds.jwt.JWTClaimsSet;
import com.nimbusds.jwt.SignedJWT;

import org.eclipse.edc.identityhub.protocols.oid4vci.spi.CredentialGenerator;
import org.eclipse.edc.spi.monitor.Monitor;
import org.eclipse.edc.spi.result.Result;
import org.eclipse.edc.spi.security.Vault;

public class GxdchCredentialGenerator implements CredentialGenerator {

	private static final String GAIAX_TERMS_HASH = "067dcac5efd18c1927deb1ffed3feab6d0ad044c0a9a263e6d5d8bdc43224515";
	private static final List<String> CONTEXT = List.of(
			"https://www.w3.org/ns/credentials/v2",
			"https://w3id.org/gaia-x/development#");

	private final GxdchClient client;
	private final Vault vault;
	private final Monitor monitor;
	private final GxdchConfig config;

	public GxdchCredentialGenerator(GxdchClient client, Vault vault, Monitor monitor,
			GxdchConfig config) {
		this.client = client;
		this.vault = vault;
		this.monitor = monitor;
		this.config = config;
	}

	private Result<String> fetchRegistrationCredential(String participantDid, String baseId) {
		var vcId = baseId + "#registration-number";
		var subjectId = baseId + "#cs";

		if (config.leiCode() != null && !config.leiCode().isBlank()) {
			return client.requestLeiCodeCredential(config.leiCode(), vcId, subjectId);
		}
		if (config.vatId() != null && !config.vatId().isBlank()) {
			return client.requestVatIdCredential(config.vatId(), vcId, subjectId);
		}
		if (config.eori() != null && !config.eori().isBlank()) {
			return client.requestEoriCredential(config.eori(), vcId, subjectId);
		}
		if (config.euid() != null && !config.euid().isBlank()) {
			return client.requestEuidCredential(config.euid(), vcId, subjectId);
		}
		return Result.failure("No registration number configured (lei/vat/eori/euid)");
	}

	private Map<String, Object> buildLegalPersonCredential(String participantDid, String baseId,
			String registrationVcId) {
		var credential = new LinkedHashMap<String, Object>();
		credential.put("@context", CONTEXT);
		credential.put("type", List.of("VerifiableCredential", "gx:LegalPerson"));
		credential.put("id", baseId + "/legal-person.json");
		credential.put("issuer", participantDid);
		credential.put("validFrom", Instant.now().toString());

		var subject = new LinkedHashMap<String, Object>();
		subject.put("id", baseId + "/legal-person.json#cs");
		subject.put("https://schema.org/name", config.legalName());
		subject.put("gx:registrationNumber", Map.of("id", registrationVcId));
		subject.put("gx:headquartersAddress", Map.of(
				"type",
				"gx:Address",
				"gx:countryCode",
				config.countryCode()));
		subject.put("gx:legalAddress", Map.of(
				"type",
				"gx:Address",
				"gx:countryCode",
				config.countryCode()));
		credential.put("credentialSubject", subject);
		return credential;
	}

	private Map<String, Object> buildIssuerCredential(String participantDid, String baseId) {
		var credential = new LinkedHashMap<String, Object>();
		credential.put("@context", CONTEXT);
		credential.put("type", List.of("VerifiableCredential", "gx:Issuer"));
		credential.put("id", baseId + "/terms-and-conditions.json");
		credential.put("issuer", participantDid);
		credential.put("validFrom", Instant.now().toString());

		var subject = new LinkedHashMap<String, Object>();
		subject.put("id", baseId + "/terms-and-conditions.json#cs");
		subject.put("gaiaxTermsAndConditions", config.termsHash() != null ? config.termsHash() : GAIAX_TERMS_HASH);

		credential.put("credentialSubject", subject);

		return credential;
	}

	private Map<String, Object> buildVerifiablePresentation(List<String> vcJwts) {
		var vp = new LinkedHashMap<String, Object>();
		vp.put("@context", CONTEXT);
		vp.put("type", "VerifiablePresentation");
		vp.put("verifiableCredential",
				vcJwts.stream().map(
						jwt -> Map.of("id", "data:application/vc+jwt," + jwt, "type", "EnvelopedVerifiableCredential"))
						.toList());
		return vp;
	}

	private Result<String> signJwt(String issuerDid, Map<String, Object> payload, String jwtType, String cty) {
		try {
			var keyJson = vault.resolveSecret(config.signingKeyAlias());
			if (keyJson == null) {
				return Result.failure("Signing key not found in vault: " + config.signingKeyAlias());
			}

			var rsaKey = RSAKey.parse(keyJson);
			var now = new Date();
			var exp = new Date(now.getTime() + 90L * 24 * 60 * 60 * 1000);

			var claimsBuilder = new JWTClaimsSet.Builder().issuer(issuerDid).issueTime(now).expirationTime(exp);

			for (var entry : payload.entrySet()) {
				claimsBuilder.claim(entry.getKey(), entry.getValue());
			}

			var header = new JWSHeader.Builder(JWSAlgorithm.PS256)
					.keyID(issuerDid + "#" + config.verificationMethodId())
					.type(new JOSEObjectType(jwtType))
					.contentType(cty)
					.customParam("iss", issuerDid)
					.build();

			var jwt = new SignedJWT(header, claimsBuilder.build());
			jwt.sign(new RSASSASigner(rsaKey.toRSAPrivateKey()));
			return Result.success(jwt.serialize());
		} catch (Exception e) {
			return Result.failure("JWT signing error: " + e.getMessage());
		}
	}

	private Result<String> signCredential(String issuerDid, Map<String, Object> credential) {
		return signJwt(issuerDid, credential, "vc+jwt", "vc");
	}

	private Result<String> signVerifiablePresentation(String issuerDid, Map<String, Object> vp) {
		return signJwt(issuerDid, vp, "vp+jwt", "vp");
	}

	@Override
	public Result<String> generate(GenerationRequest request) {
		try {
			var participantDid = (config.publicDid() != null && !config.publicDid().isBlank()) ? config.publicDid()
					: request.issuerDid();
			var baseId = config.baseId();

			monitor.info("GXDCH starting credential generation for %s".formatted(participantDid));

			var registrationResult = fetchRegistrationCredential(participantDid, baseId);
			if (registrationResult.failed()) {
				return Result.failure(registrationResult.getFailureMessages());
			}
			var registrationVcJwt = registrationResult.getContent();
			var registrationVcId = baseId + "#registration-number";

			var legalPerson = buildLegalPersonCredential(participantDid, baseId, registrationVcId);
			var legalPersonJwt = signCredential(participantDid, legalPerson);
			if (legalPersonJwt.failed()) {
				return Result.failure(legalPersonJwt.getFailureMessages());
			}

			var issuer = buildIssuerCredential(participantDid, baseId);
			var issuerJwt = signCredential(participantDid, issuer);
			if (issuerJwt.failed()) {
				return Result.failure(issuerJwt.getFailureMessages());
			}

			var vp = buildVerifiablePresentation(List.of(
					legalPersonJwt.getContent(),
					registrationVcJwt,
					issuerJwt.getContent()));

			var vpJwtResult = signVerifiablePresentation(participantDid, vp);
			if (vpJwtResult.failed()) {
				return Result.failure(vpJwtResult.getFailureMessages());
			}

			var vcId = baseId + "#" + UUID.randomUUID();
			var complianceResult = client.requestComplianceCredential(vpJwtResult.getContent(), vcId,
					config.complianceLevel());
			if (complianceResult.failed()) {
				return Result.failure(complianceResult.getFailureMessages());
			}

			monitor.info("GXDCH label credential issued for %s".formatted(participantDid));
			return Result.success(complianceResult.getContent());
		} catch (Exception e) {
			monitor.warning("GXDCH generation failed: " + e.getMessage());
			return Result.failure("GXDCH generation error: " + e.getMessage());
		}
	}
}
