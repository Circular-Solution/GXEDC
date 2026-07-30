package org.eclipse.edc.accesspolicy;

import org.eclipse.edc.connector.controlplane.catalog.spi.policy.CatalogPolicyContext;
import org.eclipse.edc.connector.controlplane.contract.spi.policy.ContractNegotiationPolicyContext;
import org.eclipse.edc.connector.controlplane.contract.spi.policy.TransferProcessPolicyContext;
import org.eclipse.edc.policy.engine.spi.AtomicConstraintRuleFunction;
import org.eclipse.edc.policy.engine.spi.PolicyContext;
import org.eclipse.edc.policy.engine.spi.PolicyEngine;
import org.eclipse.edc.policy.engine.spi.RuleBindingRegistry;
import org.eclipse.edc.policy.model.Permission;
import org.eclipse.edc.runtime.metamodel.annotation.Extension;
import org.eclipse.edc.runtime.metamodel.annotation.Inject;
import org.eclipse.edc.spi.system.ServiceExtension;
import org.eclipse.edc.spi.system.ServiceExtensionContext;

import static org.eclipse.edc.policy.model.OdrlNamespace.ODRL_SCHEMA;

@Extension(value = "Connector DID Access Policy Extension")
public class AccessPolicyExtension implements ServiceExtension {

  @Inject
  private PolicyEngine policyEngine;
  @Inject
  private RuleBindingRegistry ruleBindingRegistry;

  private <C extends PolicyContext> void bindPermissionFunction(AtomicConstraintRuleFunction<Permission, C> function,
      Class<C> contextClass, String scope, String constraintType) {
    ruleBindingRegistry.bind("use", scope);
    ruleBindingRegistry.bind(ODRL_SCHEMA + "use", scope);
    ruleBindingRegistry.bind(constraintType, scope);
    policyEngine.registerFunction(contextClass, Permission.class, constraintType, function);
  }

  @Override
  public void initialize(ServiceExtensionContext context) {
    bindPermissionFunction(ConnectorDidFunction.create(), CatalogPolicyContext.class,
        CatalogPolicyContext.CATALOG_SCOPE, ConnectorDidFunction.CONSTRAINT_KEY);
    bindPermissionFunction(ConnectorDidFunction.create(), ContractNegotiationPolicyContext.class,
        ContractNegotiationPolicyContext.NEGOTIATION_SCOPE, ConnectorDidFunction.CONSTRAINT_KEY);
    bindPermissionFunction(ConnectorDidFunction.create(), TransferProcessPolicyContext.class,
        TransferProcessPolicyContext.TRANSFER_SCOPE, ConnectorDidFunction.CONSTRAINT_KEY);

    context.getMonitor().info("ConnectorDid access policy function registered");
  }
}
