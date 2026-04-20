package org.eclipse.edc.gaiax.issuer;

import org.eclipse.edc.gaiax.issuer.spi.VcPublisher;
import org.eclipse.edc.identityhub.protocols.oid4vci.spi.CredentialGenerator;
import org.eclipse.edc.runtime.metamodel.annotation.Extension;
import org.eclipse.edc.runtime.metamodel.annotation.Inject;
import org.eclipse.edc.runtime.metamodel.annotation.Provider;
import org.eclipse.edc.runtime.metamodel.annotation.Setting;
import org.eclipse.edc.spi.security.Vault;
import org.eclipse.edc.spi.system.ServiceExtension;
import org.eclipse.edc.spi.system.ServiceExtensionContext;

@Extension(value = GxdchIssuerExtension.NAME)
public class GxdchIssuerExtension implements ServiceExtension {

	public static final String NAME = "Gaia-X GXDCH Credential Issuer Extension";

	@Setting(description = "GXDCH notary base URL", key = "edc.gaiax.gxdch.notary.url", defaultValue = "https://registrationnumber.notary.lab.gaia-x.eu/v2")
	private String notaryUrl;

	@Setting(description = "GXDCH compliance base URL", key = "edc.gaiax.gxdch.compliance.url", defaultValue = "https://compliance.lab.gaia-x.eu/v2")
	private String complianceUrl;

	@Setting(description = "Base ID URL for self-signed credentials (must be a public URL)", key = "edc.gaiax.gxdch.base.id", defaultValue = "https://example.com/participant")
	private String baseId;

	@Setting(description = "Legal entity name", key = "edc.gaiax.gxdch.legal.name", defaultValue = "Example Company")
	private String legalName;

	@Setting(description = "Two-letter country code", key = "edc.gaiax.gxdch.country.code", defaultValue = "KR")
	private String countryCode;

	@Setting(description = "LEI code (optional)", key = "edc.gaiax.gxdch.lei", defaultValue = "", required = false)
	private String leiCode;

	@Setting(description = "VAT ID (optional)", key = "edc.gaiax.gxdch.vat", defaultValue = "", required = false)
	private String vatId;

	@Setting(description = "EORI (optional)", key = "edc.gaiax.gxdch.eori", defaultValue = "", required = false)
	private String eori;

	@Setting(description = "EUID (optional)", key = "edc.gaiax.gxdch.euid", defaultValue = "", required = false)
	private String euid;

	@Setting(description = "Compliance level: standard-compliance, label-level-1, label-level-2, label-level-3", key = "edc.gaiax.gxdch.compliance.level", defaultValue = "standard-compliance")
	private String complianceLevel;

	@Setting(description = "Vault alias for the participant signing key", key = "edc.gaiax.gxdch.signing.key.alias", defaultValue = "gxdch-signing-key")
	private String signingKeyAlias;

	@Setting(description = "Verification method fragment in DID document (Gaia-X convention: X509-JWK)", key = "edc.gaiax.gxdch.verification.method.id", defaultValue = "X509-JWK")
	private String verificationMethodId;

	@Setting(description = "Gaia-X terms and conditions hash", key = "edc.gaiax.gxdch.terms.hash", defaultValue = "067dcac5efd18c1927deb1ffed3feab6d0ad044c0a9a263e6d5d8bdc43224515")
	private String termsHash;

	@Setting(description = "Public DID override (ex: did:web:your-domain). Falls back to participant DID if empty", key = "edc.gaiax.gxdch.public.did", defaultValue = "", required = false)
	private String publicDid;

	@Inject
	private Vault vault;

	@Inject
	private VcPublisher vcPublisher;

	@Override
	public String name() {
		return NAME;
	}

	@Provider(isDefault = true)
	public VcPublisher defaultVcPublisher() {
		return new NoopVcPublisher();
	}

	@Provider
	public CredentialGenerator credentialGenerator(ServiceExtensionContext context) {
		var config = new GxdchConfig(publicDid, baseId, legalName, countryCode, leiCode, vatId, eori, euid,
				complianceLevel,
				signingKeyAlias, verificationMethodId, termsHash);
		var monitor = context.getMonitor().withPrefix("GXDCH-Issuer");
		var client = new GxdchClient(notaryUrl, complianceUrl, monitor);
		return new GxdchCredentialGenerator(client, vault, monitor, config, vcPublisher);
	}

}
