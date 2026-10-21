<?php

declare(strict_types=1);

namespace App\Controller;

use App\Repository\UserRepository;
use Symfony\Component\HttpFoundation\JsonResponse;
use Symfony\Component\HttpFoundation\Request;
use Symfony\Component\HttpKernel\Exception\NotFoundHttpException;
use Symfony\Component\Routing\Attribute\Route;

/**
 * Internal-only endpoint used by the Keycloak eCamp User Storage SPI (see
 * dev-setup/keycloak/spi/ecamp-user-storage) to check whether a real eCamp user exists for
 * a given identifier, and to fetch the name Keycloak needs for a federated user's profile.
 *
 * Gated by a pre-shared secret (X-Internal-Auth) rather than normal user auth, since the
 * caller is the Keycloak server, not a logged-in eCamp user. A missing/wrong secret returns
 * 404 (not 401/403) so this endpoint is indistinguishable from a route that doesn't exist
 * to anyone without the secret -- eCamp does not otherwise reveal account existence via API
 * responses, see ResetPasswordCreateProcessor for the same posture.
 */
class InternalUserLookupController {
    public function __construct(
        private readonly UserRepository $userRepository,
        private readonly string $sharedSecret,
    ) {}

    #[Route('/internal/user-lookup', name: 'internal_user_lookup', methods: ['POST'])]
    public function __invoke(Request $request): JsonResponse {
        $providedSecret = $request->headers->get('X-Internal-Auth');
        if ('' === $this->sharedSecret || !is_string($providedSecret) || !hash_equals($this->sharedSecret, $providedSecret)) {
            throw new NotFoundHttpException();
        }

        $data = json_decode($request->getContent(), true);
        $identifier = is_array($data) ? ($data['identifier'] ?? null) : null;
        if (!is_string($identifier) || '' === $identifier) {
            throw new NotFoundHttpException();
        }

        $user = $this->userRepository->loadUserByIdentifier($identifier);
        if (null === $user) {
            return new JsonResponse(['exists' => false]);
        }

        return new JsonResponse([
            'exists' => true,
            'firstName' => $user->getProfile()->firstname,
            'lastName' => $user->getProfile()->surname,
        ]);
    }
}
