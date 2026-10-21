package ch.ecamp.keycloak;

import org.keycloak.component.ComponentModel;
import org.keycloak.models.KeycloakSession;
import org.keycloak.models.RealmModel;
import org.keycloak.storage.adapter.AbstractUserAdapterFederatedStorage;

/**
 * Represents an eCamp user inside Keycloak. Identity (email as username) is read-only
 * here -- eCamp's own database remains the source of truth, this is just a view onto it.
 */
public class EcampUserAdapter extends AbstractUserAdapterFederatedStorage {

    private final String email;

    public EcampUserAdapter(
            KeycloakSession session,
            RealmModel realm,
            ComponentModel storageProviderModel,
            String email,
            String firstName,
            String lastName) {
        super(session, realm, storageProviderModel);
        this.email = email;
        setSingleAttribute("email", email);
        // Required attributes per Keycloak's default User Profile config -- without these,
        // every login triggers Keycloak's own "Update Account Information" required action.
        if (firstName != null) {
            setFirstName(firstName);
        }
        if (lastName != null) {
            setLastName(lastName);
        }
    }

    @Override
    public String getUsername() {
        return email;
    }

    @Override
    public void setUsername(String username) {
        // Read-only: identity is managed by eCamp, not by Keycloak.
    }

    @Override
    public String getEmail() {
        return email;
    }

    @Override
    public boolean isEmailVerified() {
        return true;
    }
}
