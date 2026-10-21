package ch.ecamp.keycloak;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.keycloak.component.ComponentModel;
import org.keycloak.credential.CredentialInput;
import org.keycloak.credential.CredentialInputValidator;
import org.keycloak.models.KeycloakSession;
import org.keycloak.models.RealmModel;
import org.keycloak.models.UserModel;
import org.keycloak.models.credential.PasswordCredentialModel;
import org.keycloak.storage.StorageId;
import org.keycloak.storage.UserStorageProvider;
import org.keycloak.storage.user.UserLookupProvider;

import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.time.Duration;
import java.util.regex.Pattern;

/**
 * Local-dev-only proof of concept: validates eCamp password logins live against eCamp's
 * own POST /authentication_token endpoint (api/config/packages/security.yaml json_login),
 * instead of storing or verifying a password hash inside Keycloak. The password is
 * checked on every login, never persisted here.
 *
 * See dev-setup/keycloak/README.md for the design rationale and known limitations.
 */
public class EcampUserStorageProvider implements UserStorageProvider, UserLookupProvider, CredentialInputValidator {

    private static final Pattern EMAIL_PATTERN = Pattern.compile("^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$");

    private final KeycloakSession session;
    private final ComponentModel model;
    private final String ecampApiBaseUrl;
    private final String internalApiSecret;
    private final HttpClient httpClient;
    private final ObjectMapper objectMapper = new ObjectMapper();

    public EcampUserStorageProvider(KeycloakSession session, ComponentModel model) {
        this.session = session;
        this.model = model;
        this.ecampApiBaseUrl = model.get("ecampApiBaseUrl", "http://api:3001");
        this.internalApiSecret = model.get("internalApiSecret", "");
        this.httpClient = HttpClient.newBuilder()
                .connectTimeout(Duration.ofSeconds(5))
                .build();
    }

    @Override
    public UserModel getUserByUsername(RealmModel realm, String username) {
        if (username == null || !EMAIL_PATTERN.matcher(username).matches()) {
            return null;
        }

        EcampUserLookupResult lookup = lookupEcampUser(username);
        if (lookup == null || !lookup.exists()) {
            return null;
        }
        return new EcampUserAdapter(session, realm, model, username, lookup.firstName(), lookup.lastName());
    }

    private record EcampUserLookupResult(boolean exists, String firstName, String lastName) {
    }

    /**
     * Calls eCamp's internal, shared-secret-gated /internal/user-lookup endpoint (see
     * api/src/Controller/InternalUserLookupController.php) to check whether a real eCamp
     * user exists for the given identifier, and to fetch the name Keycloak's default User
     * Profile config requires. Returns null on any network/parse error (fail closed -- an
     * unreachable eCamp API must never be treated as "user exists").
     */
    private EcampUserLookupResult lookupEcampUser(String identifier) {
        try {
            String body = "{\"identifier\":" + jsonString(identifier) + "}";

            HttpRequest request = HttpRequest.newBuilder()
                    .uri(URI.create(ecampApiBaseUrl + "/internal/user-lookup"))
                    .header("Content-Type", "application/json")
                    .header("X-Internal-Auth", internalApiSecret)
                    .timeout(Duration.ofSeconds(5))
                    .POST(HttpRequest.BodyPublishers.ofString(body))
                    .build();

            HttpResponse<String> response = httpClient.send(request, HttpResponse.BodyHandlers.ofString());
            if (response.statusCode() != 200) {
                return null;
            }

            JsonNode json = objectMapper.readTree(response.body());
            boolean exists = json.path("exists").asBoolean(false);
            if (!exists) {
                return new EcampUserLookupResult(false, null, null);
            }
            String firstName = json.path("firstName").asText(null);
            String lastName = json.path("lastName").asText(null);
            return new EcampUserLookupResult(true, firstName, lastName);
        } catch (Exception e) {
            return null;
        }
    }

    @Override
    public UserModel getUserById(RealmModel realm, String id) {
        StorageId storageId = new StorageId(id);
        return getUserByUsername(realm, storageId.getExternalId());
    }

    @Override
    public UserModel getUserByEmail(RealmModel realm, String email) {
        return getUserByUsername(realm, email);
    }

    @Override
    public boolean supportsCredentialType(String credentialType) {
        return PasswordCredentialModel.TYPE.equals(credentialType);
    }

    @Override
    public boolean isConfiguredFor(RealmModel realm, UserModel user, String credentialType) {
        return supportsCredentialType(credentialType);
    }

    @Override
    public boolean isValid(RealmModel realm, UserModel user, CredentialInput input) {
        if (!supportsCredentialType(input.getType())) {
            return false;
        }
        String password = input.getChallengeResponse();
        if (password == null || password.isEmpty()) {
            return false;
        }

        try {
            String body = "{\"identifier\":" + jsonString(user.getUsername())
                    + ",\"password\":" + jsonString(password) + "}";

            HttpRequest request = HttpRequest.newBuilder()
                    .uri(URI.create(ecampApiBaseUrl + "/authentication_token"))
                    .header("Content-Type", "application/json")
                    .timeout(Duration.ofSeconds(5))
                    .POST(HttpRequest.BodyPublishers.ofString(body))
                    .build();

            HttpResponse<Void> response = httpClient.send(request, HttpResponse.BodyHandlers.discarding());
            // eCamp's /authentication_token returns 204 on success.
            return response.statusCode() == 204;
        } catch (Exception e) {
            // Fail closed: a network error or timeout rejects the login attempt, it never
            // falls back to treating an unreachable eCamp API as a valid password.
            return false;
        }
    }

    private static String jsonString(String value) {
        return "\"" + value.replace("\\", "\\\\").replace("\"", "\\\"") + "\"";
    }

    @Override
    public void close() {
    }
}
