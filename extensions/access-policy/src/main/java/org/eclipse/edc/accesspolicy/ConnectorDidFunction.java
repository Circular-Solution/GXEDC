package org.eclipse.edc.accesspolicy;

import java.util.List;

import org.eclipse.edc.participant.spi.ParticipantAgentPolicyContext;
import org.eclipse.edc.policy.engine.spi.AtomicConstraintRuleFunction;
import org.eclipse.edc.policy.model.Operator;
import org.eclipse.edc.policy.model.Permission;

public class ConnectorDidFunction<C extends ParticipantAgentPolicyContext>
    implements AtomicConstraintRuleFunction<Permission, C> {
  public static final String CONSTRAINT_KEY = "https://w3id.org/edc/v0.0.1/ns/ConnectorDid";

  private ConnectorDidFunction() {
  }

  public static <C extends ParticipantAgentPolicyContext> ConnectorDidFunction<C> create() {
    return new ConnectorDidFunction<>() {
    };
  }

  @Override
  public boolean evaluate(Operator operator, Object rightOperand, Permission permission, C policyContext) {
    var agent = policyContext.participantAgent();
    if (agent == null || agent.getIdentity() == null) {
      policyContext.reportProblem("ConnectorDid: no ParticipantAgent identity on context");
      return false;
    }

    var allowed = toValues(rightOperand);
    if (allowed.isEmpty()) {
      policyContext.reportProblem("ConnectorDid: right-operand is empty");
      return false;
    }

    var match = allowed.contains(agent.getIdentity());
    return switch (operator) {
      case EQ, IN, IS_ANY_OF -> match;
      case NEQ, IS_NONE_OF -> !match;
      default -> {
        policyContext.reportProblem("ConnectorDid: unsupported operator '%s'".formatted(operator));
        yield false;
      }
    };
  }

  private List<String> toValues(Object rightOperand) {
    if (rightOperand instanceof List<?> list) {
      return list.stream().map(Object::toString).toList();
    }
    return rightOperand == null ? List.of() : List.of(rightOperand.toString());
  }
}
