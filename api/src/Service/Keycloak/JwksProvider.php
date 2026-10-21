<?php

declare(strict_types=1);

namespace App\Service\Keycloak;

use Lcobucci\JWT\Signer\Key;
use Lcobucci\JWT\Signer\Key\InMemory;
use Symfony\Contracts\Cache\CacheInterface;
use Symfony\Contracts\Cache\ItemInterface;
use Symfony\Contracts\HttpClient\HttpClientInterface;

/**
 * Fetches and caches Keycloak's JWKS, so incoming bearer tokens can be verified without
 * a network round-trip to Keycloak on every API request. Local-dev-only proof of concept,
 * see App\Security\OAuth\KeycloakBearerAuthenticator.
 */
class JwksProvider {
    public function __construct(
        private readonly HttpClientInterface $httpClient,
        private readonly CacheInterface $cache,
        private readonly string $jwksUri,
    ) {}

    public function getKey(string $kid): ?Key {
        $keys = $this->cache->get('keycloak_jwks', function (ItemInterface $item) {
            $item->expiresAfter(300);

            return $this->httpClient->request('GET', $this->jwksUri)->toArray()['keys'] ?? [];
        });

        foreach ($keys as $jwk) {
            if (($jwk['kid'] ?? null) === $kid && isset($jwk['x5c'][0])) {
                return InMemory::plainText($this->certificateToPublicKeyPem($jwk['x5c'][0]));
            }
        }

        return null;
    }

    private function certificateToPublicKeyPem(string $x5c): string {
        $certificatePem = "-----BEGIN CERTIFICATE-----\n".chunk_split($x5c, 64, "\n")."-----END CERTIFICATE-----\n";

        $publicKey = openssl_pkey_get_public($certificatePem);
        if (false === $publicKey) {
            throw new \RuntimeException('Could not extract a public key from the Keycloak JWKS certificate');
        }

        $details = openssl_pkey_get_details($publicKey);
        if (false === $details) {
            throw new \RuntimeException('Could not read details of the Keycloak JWKS public key');
        }

        return $details['key'];
    }
}
