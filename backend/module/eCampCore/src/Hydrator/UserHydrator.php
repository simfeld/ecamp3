<?php

namespace eCamp\Core\Hydrator;

use eCamp\Core\Entity\User;
use eCamp\Lib\Hydrator\Util;
use Laminas\Authentication\AuthenticationService;
use Laminas\Hydrator\HydratorInterface;

class UserHydrator implements HydratorInterface {
    public static function HydrateInfo() {
        return [
        ];
    }

    /**
     * @param object $object
     *
     * @return array
     */
    public function extract($object) {
        $auth = new AuthenticationService();
        /** @var User $user */
        $user = $object;

        $relation = $user->getRelation($auth->getIdentity());
        $showDetails = (User::RELATION_UNRELATED != $relation);

        return [
            'id' => $user->getId(),
            'username' => $user->getUsername(),
            'mail' => $showDetails ? $user->getTrustedMailAddress() : '***',
            'relation' => $relation,
            'role' => $user->getRole(),
        ];
    }

    /**
     * @param object $object
     *
     * @return object
     */
    public function hydrate(array $data, $object) {
        /** @var User $user */
        $user = $object;

        if (isset($data['username'])) {
            $user->setUsername($data['username']);
        }
        if (isset($data['firstname'])) {
            $user->setFirstname($data['firstname']);
        }
        if (isset($data['surname'])) {
            $user->setSurname($data['surname']);
        }
        if (isset($data['birthday'])) {
            $user->setBirthday(Util::parseDate($data['birthday']));
        }
        if (isset($data['language'])) {
            $user->setLanguage($data['language']);
        }

        return $user;
    }
}
