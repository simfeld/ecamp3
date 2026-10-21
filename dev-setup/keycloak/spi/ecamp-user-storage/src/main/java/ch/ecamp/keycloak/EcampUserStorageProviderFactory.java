package ch.ecamp.keycloak;

import org.keycloak.component.ComponentModel;
import org.keycloak.models.KeycloakSession;
import org.keycloak.provider.ProviderConfigProperty;
import org.keycloak.storage.UserStorageProviderFactory;

import java.util.ArrayList;
import java.util.List;

public class EcampUserStorageProviderFactory implements UserStorageProviderFactory<EcampUserStorageProvider> {

    public static final String PROVIDER_ID = "ecamp-user-storage";

    @Override
    public String getId() {
        return PROVIDER_ID;
    }

    @Override
    public EcampUserStorageProvider create(KeycloakSession session, ComponentModel model) {
        return new EcampUserStorageProvider(session, model);
    }

    @Override
    public List<ProviderConfigProperty> getConfigProperties() {
        // Undeclared config keys are silently dropped by Keycloak's realm import
        // (RepresentationToModel validates component config against this list), so
        // ecampApiBaseUrl must be declared here even though it's only ever read directly
        // from ComponentModel in EcampUserStorageProvider, never via this metadata.
        ProviderConfigProperty ecampApiBaseUrl = new ProviderConfigProperty();
        ecampApiBaseUrl.setName("ecampApiBaseUrl");
        ecampApiBaseUrl.setLabel("eCamp API base URL");
        ecampApiBaseUrl.setType(ProviderConfigProperty.STRING_TYPE);
        ecampApiBaseUrl.setHelpText("Base URL of the eCamp API used to validate password logins.");

        ProviderConfigProperty internalApiSecret = new ProviderConfigProperty();
        internalApiSecret.setName("internalApiSecret");
        internalApiSecret.setLabel("eCamp internal API shared secret");
        internalApiSecret.setType(ProviderConfigProperty.PASSWORD);
        internalApiSecret.setHelpText("Shared secret sent as X-Internal-Auth when looking up whether a user exists.");

        List<ProviderConfigProperty> properties = new ArrayList<>();
        properties.add(ecampApiBaseUrl);
        properties.add(internalApiSecret);
        return properties;
    }
}
