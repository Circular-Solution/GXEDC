package org.eclipse.edc.gaiax.issuer;

public record GxdchConfig(
		String publicDid,
		String baseId,
		String legalName,
		String countryCode,
		String leiCode,
		String vatId,
		String eori,
		String euid,
		String complianceLevel,
		String signingKeyAlias,
		String verificationMethodId,
		String termsHash) {
}
