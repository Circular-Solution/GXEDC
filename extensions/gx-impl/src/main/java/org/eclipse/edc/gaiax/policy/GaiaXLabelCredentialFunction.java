package org.eclipse.edc.gaiax.policy;

import java.util.List;

import org.eclipse.edc.iam.verifiablecredentials.spi.model.VerifiableCredential;
import org.eclipse.edc.participant.spi.ParticipantAgentPolicyContext;
import org.eclipse.edc.policy.engine.spi.AtomicConstraintRuleFunction;
import org.eclipse.edc.policy.model.Operator;
import org.eclipse.edc.policy.model.Permission;
import org.eclipse.edc.spi.monitor.Monitor;

public class GaiaXLabelCredentialFunction<C extends ParticipantAgentPolicyContext>
    implements AtomicConstraintRuleFunction<Permission, C> {
  public static final String CONSTRAINT_KEY = "https://w3id.org/edc/v0.0.1/ns/GaiaXLabelCredential";

  private final GaiaXCredentialValidator validator;
  private final Monitor monitor;

  private GaiaXLabelCredentialFunction(GaiaXCredentialValidator validator, Monitor monitor) {
    this.validator = validator;
    this.monitor = monitor;
  }

  public static <C extends ParticipantAgentPolicyContext> GaiaXLabelCredentialFunction<C> create(
      GaiaXCredentialValidator validator, Monitor monitor) {
    return new GaiaXLabelCredentialFunction<>(validator, monitor) {
    };
  }

  @Override
  public boolean evaluate(Operator operator, Object rightOperand, Permission permission, C policyContext) {
    monitor.info("GaiaXLabelCredential policy evaluating, operator=%s rightOperand=%s".formatted(operator, rightOperand));

    if (!operator.equals(Operator.EQ)) {
      monitor.warning("GaiaXLabelCredential: invalid operator " + operator);
      policyContext.reportProblem("Invalid operator '%s', only accepts '%s'".formatted(operator, Operator.EQ));
      return false;
    }
    if (!"active".equals(rightOperand)) {
      monitor.warning("GaiaXLabelCredential: invalid rightOperand " + rightOperand);
      policyContext.reportProblem("Right-operand must be 'active', but was '%s'".formatted(rightOperand));
      return false;
    }

    var pa = policyContext.participantAgent();
    if (pa == null) {
      monitor.warning("GaiaXLabelCredential: no ParticipantAgent");
      policyContext.reportProblem("No ParticipantAgent found on context");
      return false;
    }

    var vcClaim = pa.getClaims().get("vc");
    if (!(vcClaim instanceof List<?> vcList) || vcList.isEmpty()) {
      monitor.warning("GaiaXLabelCredential: vc claim missing or empty. Claims: " + pa.getClaims().keySet());
      policyContext.reportProblem("'vc' claim missing or empty");
      return false;
    }

    monitor.info("GaiaXLabelCredential: evaluating %d VCs".formatted(vcList.size()));

    var vcJwtClaim = pa.getClaims().get("vc_jwt");
    var vcJwtList = vcJwtClaim instanceof List<?> jwtList ? jwtList : List.of();

    for (int i = 0; i < vcList.size(); i++) {
      var item = vcList.get(i);
      if (item instanceof VerifiableCredential vc) {
        var rawJwt = i < vcJwtList.size() && vcJwtList.get(i) instanceof String s ? s : null;
        var result = validator.validate(vc, rawJwt);
        if (result.succeeded()) {
          monitor.info("GaiaXLabelCredential: VC %d passed validation".formatted(i));
          return true;
        }
        monitor.warning("GaiaXLabelCredential: VC %d failed: %s".formatted(i, result.getFailureDetail()));
        policyContext.reportProblem("VC failed Gaia-X validation: " + result.getFailureDetail());
      } else {
        monitor.warning("GaiaXLabelCredential: item %d is not a VerifiableCredential: %s".formatted(i, item));
      }
    }
    monitor.warning("GaiaXLabelCredential: no VC passed validation");
    return false;
  }
}
