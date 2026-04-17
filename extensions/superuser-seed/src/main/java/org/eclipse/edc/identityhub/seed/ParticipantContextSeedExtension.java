/*
 *  Copyright (c) 2024 Metaform Systems, Inc.
 *
 *  This program and the accompanying materials are made available under the
 *  terms of the Apache License, Version 2.0 which is available at
 *  https://www.apache.org/licenses/LICENSE-2.0
 *
 *  SPDX-License-Identifier: Apache-2.0
 *
 *  Contributors:
 *       Metaform Systems, Inc. - initial API and implementation
 *       Circular Solution Co., Ltd - update to EDC 0.16
 *
 */

package org.eclipse.edc.identityhub.seed;

import static java.util.Optional.ofNullable;

import java.util.List;
import java.util.Map;

import org.eclipse.edc.spi.query.QuerySpec;

import org.eclipse.edc.participantcontext.spi.config.service.ParticipantContextConfigService;
import org.eclipse.edc.participantcontext.spi.config.model.ParticipantContextConfiguration;
import org.eclipse.edc.identityhub.spi.authentication.ServicePrincipal;
import org.eclipse.edc.identityhub.spi.participantcontext.IdentityHubParticipantContextService;
import org.eclipse.edc.identityhub.spi.participantcontext.model.KeyDescriptor;
import org.eclipse.edc.identityhub.spi.participantcontext.model.ParticipantManifest;
import org.eclipse.edc.runtime.metamodel.annotation.Inject;
import org.eclipse.edc.runtime.metamodel.annotation.Setting;
import org.eclipse.edc.spi.EdcException;
import org.eclipse.edc.spi.monitor.Monitor;
import org.eclipse.edc.spi.security.Vault;
import org.eclipse.edc.spi.system.ServiceExtension;
import org.eclipse.edc.spi.system.ServiceExtensionContext;

public class ParticipantContextSeedExtension implements ServiceExtension {
    public static final String NAME = "MVD ParticipantContext Seed Extension";
    public static final String DEFAULT_SUPER_USER_PARTICIPANT_ID = "super-user";

    @Setting(description = "Explicitly set the initial API key for the Super-User")
    public static final String SUPERUSER_APIKEY_PROPERTY = "edc.ih.api.superuser.key";

    @Setting(description = "Config value to set the super-user's participant ID.", defaultValue = DEFAULT_SUPER_USER_PARTICIPANT_ID)
    public static final String SUPERUSER_PARTICIPANT_ID_PROPERTY = "edc.ih.api.superuser.id";
    private String superUserParticipantId;
    private String superUserApiKey;
    private Monitor monitor;
    @Inject
    private IdentityHubParticipantContextService participantContextService;
    @Inject
    private Vault vault;

    @Inject
    private ParticipantContextConfigService configStore;

    @Override
    public String name() {
        return NAME;
    }

    @Override
    public void initialize(ServiceExtensionContext context) {
        superUserParticipantId = context.getSetting(SUPERUSER_PARTICIPANT_ID_PROPERTY,
                DEFAULT_SUPER_USER_PARTICIPANT_ID);
        superUserApiKey = context.getSetting(SUPERUSER_APIKEY_PROPERTY, null);
        monitor = context.getMonitor();
    }

    @Override
    public void start() {
        // create super-user
        if (participantContextService.getParticipantContext(superUserParticipantId).succeeded()) { // already exists
            monitor.debug(
                    "super-user already exists with ID '%s', will not re-create".formatted(superUserParticipantId));
            if (configStore.get(superUserParticipantId).failed()) {
                configStore.save(ParticipantContextConfiguration.Builder.newInstance()
                        .participantContextId(superUserParticipantId)
                        .build());
            }
            if (superUserApiKey != null) {
                participantContextService.getParticipantContext(superUserParticipantId)
                        .onSuccess(pc -> vault.storeSecret(pc.getApiTokenAlias(), superUserApiKey)
                                .onSuccess(u -> monitor.info("Re-stored super-user API key in vault"))
                                .onFailure(f -> monitor.warning("Error re-storing API key: %s".formatted(f.getFailureDetail()))));
            }
            seedMissingConfigs();
            return;
        }
        configStore.save(ParticipantContextConfiguration.Builder.newInstance()
                .participantContextId(superUserParticipantId)
                .build());
        monitor.info("Seeded participant context config for '%s'".formatted(superUserParticipantId));

        participantContextService.createParticipantContext(ParticipantManifest.Builder.newInstance()
                .participantContextId(superUserParticipantId)
                .did("did:web:%s".formatted(superUserParticipantId)) // doesn't matter, not intended for resolution
                .active(true)
                .key(KeyDescriptor.Builder.newInstance()
                        .keyGeneratorParams(Map.of("algorithm", "EdDSA", "curve", "Ed25519"))
                        .keyId("%s-key".formatted(superUserParticipantId))
                        .privateKeyAlias("%s-alias".formatted(superUserParticipantId))
                        .build())
                .roles(List.of(ServicePrincipal.ROLE_ADMIN))
                .build())
                .onSuccess(generatedKey -> {
                    var apiKey = ofNullable(superUserApiKey)
                            .map(key -> {
                                if (!key.contains(".")) {
                                    monitor.warning(
                                            "Super-user key override: this key appears to have an invalid format, you may be unable to access some APIs. It must follow the structure: 'base64(<participantId>).<random-string>'");
                                }
                                participantContextService.getParticipantContext(superUserParticipantId)
                                        .onSuccess(pc -> vault.storeSecret(pc.getApiTokenAlias(), key)
                                                .onSuccess(u -> monitor.debug("Super-user key override successful"))
                                                .onFailure(f -> monitor.warning("Error storing API key in vault: %s"
                                                        .formatted(f.getFailureDetail()))))
                                        .onFailure(f -> monitor.warning("Error overriding API key for '%s': %s"
                                                .formatted(superUserParticipantId, f.getFailureDetail())));
                                return key;
                            })
                            .orElse(generatedKey.apiKey());
                    monitor.info("Created user 'super-user'. Please take note of the API Key: %s".formatted(apiKey));
                })
                .orElseThrow(f -> new EdcException("Error creating Super-User: " + f.getFailureDetail()));

        seedMissingConfigs();
    }

    private void seedMissingConfigs() {
        participantContextService.query(QuerySpec.Builder.newInstance().build())
                .onSuccess(participants -> participants.forEach(pc -> {
                    var id = pc.getParticipantContextId();
                    if (configStore.get(id).failed()) {
                        configStore.save(ParticipantContextConfiguration.Builder.newInstance()
                                .participantContextId(id)
                                .build());
                        monitor.info("Seeded missing participant context config for '%s'".formatted(id));
                    }
                }))
                .onFailure(f -> monitor.warning("Failed to query participants: %s".formatted(f.getFailureDetail())));
    }
}
