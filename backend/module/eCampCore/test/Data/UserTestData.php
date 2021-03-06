<?php

namespace eCamp\CoreTest\Data;

use Doctrine\Common\DataFixtures\AbstractFixture;
use Doctrine\Persistence\ObjectManager;
use eCamp\Core\Entity\Login;
use eCamp\Core\Entity\User;

class UserTestData extends AbstractFixture {
    public static $USER1 = User::class.':USER1';

    public function load(ObjectManager $manager) {
        $user = new User();
        $user->setUsername('test-user');
        $user->setRole(User::ROLE_USER);
        $user->setTrustedMailAddress('test@ecamp3.dev');
        $user->setState(User::STATE_ACTIVATED);

        $login = new Login($user, 'test');

        $manager->persist($user);
        $manager->persist($login);

        $manager->flush();

        $this->addReference(self::$USER1, $user);
    }
}
