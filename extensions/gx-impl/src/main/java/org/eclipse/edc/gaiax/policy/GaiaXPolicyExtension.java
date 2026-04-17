package org.eclipse.edc.gaiax.policy;

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
import org.eclipse.edc.runtime.metamodel.annotation.Setting;
import org.eclipse.edc.spi.system.ServiceExtension;
import org.eclipse.edc.spi.system.ServiceExtensionContext;

import static org.eclipse.edc.policy.model.OdrlNamespace.ODRL_SCHEMA;

@Extension(value = "Gaia-X Label Credential Policy Extension")
public class GaiaXPolicyExtension implements ServiceExtension {

  @Setting(description = "Gaia-X Basic Functions API base URL (leave empty to skip remote validation)", key = "edc.gaiax.basic.functions.url", defaultValue = "")
  private String basicFunctionsUrl;

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
    var monitor = context.getMonitor().withPrefix("GaiaX-Policy");
    var validator = new GaiaXCredentialValidator(basicFunctionsUrl);

    bindPermissionFunction(GaiaXLabelCredentialFunction.create(validator, monitor), CatalogPolicyContext.class,
        CatalogPolicyContext.CATALOG_SCOPE, GaiaXLabelCredentialFunction.CONSTRAINT_KEY);
    bindPermissionFunction(GaiaXLabelCredentialFunction.create(validator, monitor), ContractNegotiationPolicyContext.class,
        ContractNegotiationPolicyContext.NEGOTIATION_SCOPE, GaiaXLabelCredentialFunction.CONSTRAINT_KEY);
    bindPermissionFunction(GaiaXLabelCredentialFunction.create(validator, monitor), TransferProcessPolicyContext.class,
        TransferProcessPolicyContext.TRANSFER_SCOPE, GaiaXLabelCredentialFunction.CONSTRAINT_KEY);

    bindPermissionFunction(GaiaXLabelLevelFunction.create(validator), CatalogPolicyContext.class,
        CatalogPolicyContext.CATALOG_SCOPE, GaiaXLabelLevelFunction.CONSTRAINT_KEY);
    bindPermissionFunction(GaiaXLabelLevelFunction.create(validator), ContractNegotiationPolicyContext.class,
        ContractNegotiationPolicyContext.NEGOTIATION_SCOPE, GaiaXLabelLevelFunction.CONSTRAINT_KEY);
    bindPermissionFunction(GaiaXLabelLevelFunction.create(validator), TransferProcessPolicyContext.class,
        TransferProcessPolicyContext.TRANSFER_SCOPE, GaiaXLabelLevelFunction.CONSTRAINT_KEY);

    context.getMonitor().info("Gaia-X policy extension registered (basic functions: %s)"
        .formatted(basicFunctionsUrl == null || basicFunctionsUrl.isBlank() ? "disabled" : basicFunctionsUrl));
  }
}
