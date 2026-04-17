package org.eclipse.edc.gaiax.policy;

import java.util.List;

import org.eclipse.edc.iam.verifiablecredentials.spi.model.VerifiableCredential;
import org.eclipse.edc.participant.spi.ParticipantAgentPolicyContext;
import org.eclipse.edc.policy.engine.spi.AtomicConstraintRuleFunction;
import org.eclipse.edc.policy.model.Operator;
import org.eclipse.edc.policy.model.Permission;

public class GaiaXLabelLevelFunction<C extends ParticipantAgentPolicyContext>
		implements AtomicConstraintRuleFunction<Permission, C> {
	public static final String CONSTRAINT_KEY = "https://w3id.org/edc/v0.0.1/ns/GaiaXLabelLevel";

	private final GaiaXCredentialValidator validator;

	private GaiaXLabelLevelFunction(GaiaXCredentialValidator validator) {
		this.validator = validator;
	}

	public static <C extends ParticipantAgentPolicyContext> GaiaXLabelLevelFunction<C> create(
			GaiaXCredentialValidator validator) {
		return new GaiaXLabelLevelFunction<>(validator) {
		};
	}

	@Override
	public boolean evaluate(Operator operator, Object rightOperand, Permission permission, C policyContext) {
		if (!operator.equals(Operator.EQ)) {
			policyContext.reportProblem("Invalid operator '%s', only accepts '%s'".formatted(operator, Operator.EQ));
			return false;
		}
		if (!(rightOperand instanceof String requiredLevel)) {
			policyContext
					.reportProblem("Right-operand must be a string (SC, L1, L2, L3), was '%s'".formatted(rightOperand));
			return false;
		}

		var pa = policyContext.participantAgent();
		if (pa == null) {
			policyContext.reportProblem("No ParticipantAgent found on context");
			return false;
		}

		var vcClaim = pa.getClaims().get("vc");
		if (!(vcClaim instanceof List<?> vcList) || vcList.isEmpty()) {
			policyContext.reportProblem("'vc' claim missing or empty");
			return false;
		}

		for (var item : vcList) {
			if (item instanceof VerifiableCredential vc) {
				var result = validator.validateLabelLevel(vc, requiredLevel);
				if (result.succeeded()) {
					return true;
				}
			}
		}
		policyContext.reportProblem("No VC matched required label level: " + requiredLevel);
		return false;
	}
}
