<?php

declare(strict_types=1);

namespace App\Security\OAuth;

use App\Entity\Profile;
use App\Service\Keycloak\JwksProvider;
use Doctrine\ORM\EntityManagerInterface;
use Lcobucci\JWT\Encoding\JoseEncoder;
use Lcobucci\JWT\Signer\Rsa\Sha256;
use Lcobucci\JWT\Token\Parser;
use Lcobucci\JWT\Token\Plain;
use Lcobucci\JWT\Validation\Constraint\IssuedBy;
use Lcobucci\JWT\Validation\Constraint\LooseValidAt;
use Lcobucci\JWT\Validation\Constraint\PermittedFor;
use Lcobucci\JWT\Validation\Constraint\SignedWith;
use Lcobucci\JWT\Validation\Validator;
use Symfony\Component\Clock\NativeClock;
use Symfony\Component\HttpFoundation\JsonResponse;
use Symfony\Component\HttpFoundation\Request;
use Symfony\Component\HttpFoundation\Response;
use Symfony\Component\Security\Core\Authentication\Token\TokenInterface;
use Symfony\Component\Security\Core\Exception\AuthenticationException;
use Symfony\Component\Security\Core\Exception\CustomUserMessageAuthenticationException;
use Symfony\Component\Security\Core\Exception\UserNotFoundException;
use Symfony\Component\Security\Http\Authenticator\AbstractAuthenticator;
use Symfony\Component\Security\Http\Authenticator\Passport\Badge\UserBadge;
use Symfony\Component\Security\Http\Authenticator\Passport\Passport;
use Symfony\Component\Security\Http\Authenticator\Passport\SelfValidatingPassport;

/**
 * Accepts Keycloak-issued OAuth2 access tokens (`Authorization: Bearer`) as an alternative
 * to the cookie-based Lexik JWT used by the eCamp frontend, for third-party applications
 * that obtained delegated access to the eCamp API through Keycloak.
 *
 * This is a local-dev-only proof of concept for third-party API access, kept fully
 * separate from the existing password/Google/Hitobito login. There is no live user
 * provisioning: the token's `email` claim must match an existing eCamp Profile (see
 * api/migrations/dev-data/DevDataInfo.md), a new eCamp account is never created here.
 */
class KeycloakBearerAuthenticator extends AbstractAuthenticator {
    public function __construct(
        private readonly JwksProvider $jwksProvider,
        private readonly EntityManagerInterface $entityManager,
        private readonly string $issuer,
        private readonly string $audience,
    ) {}

    public function supports(Request $request): ?bool {
        return str_starts_with((string) $request->headers->get('Authorization'), 'Bearer ');
    }

    public function authenticate(Request $request): Passport {
        $jwt = substr((string) $request->headers->get('Authorization'), 7);

        try {
            $token = (new Parser(new JoseEncoder()))->parse($jwt);
        } catch (\Throwable) {
            throw new CustomUserMessageAuthenticationException('Malformed bearer token');
        }

        if (!$token instanceof Plain) {
            throw new CustomUserMessageAuthenticationException('Malformed bearer token');
        }

        $kid = $token->headers()->get('kid');
        $key = is_string($kid) ? $this->jwksProvider->getKey($kid) : null;
        if (null === $key) {
            throw new CustomUserMessageAuthenticationException('Unknown bearer token signing key');
        }

        try {
            (new Validator())->assert(
                $token,
                new SignedWith(new Sha256(), $key),
                new IssuedBy($this->issuer),
                new PermittedFor($this->audience),
                new LooseValidAt(new NativeClock()),
            );
        } catch (\Throwable) {
            throw new CustomUserMessageAuthenticationException('Invalid bearer token');
        }

        $email = $token->claims()->get('email');
        if (!is_string($email) || '' === $email) {
            throw new CustomUserMessageAuthenticationException('Bearer token does not carry an email claim');
        }

        return new SelfValidatingPassport(new UserBadge($email, function (string $email) {
            $profile = $this->entityManager->getRepository(Profile::class)->findOneBy(['email' => $email]);

            if (null === $profile) {
                throw new UserNotFoundException("No eCamp account found for email {$email}");
            }

            return $profile->user;
        }));
    }

    public function onAuthenticationSuccess(Request $request, TokenInterface $token, string $firewallName): ?Response {
        return null;
    }

    public function onAuthenticationFailure(Request $request, AuthenticationException $exception): ?Response {
        $message = strtr($exception->getMessageKey(), $exception->getMessageData());

        return new JsonResponse(['message' => $message, 'code' => Response::HTTP_UNAUTHORIZED], Response::HTTP_UNAUTHORIZED);
    }
}
