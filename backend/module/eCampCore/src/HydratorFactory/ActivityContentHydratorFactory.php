<?php

namespace eCamp\Core\HydratorFactory;

use eCamp\Core\ContentType\ContentTypeStrategyProvider;
use eCamp\Core\Hydrator\ActivityContentHydrator;
use Interop\Container\ContainerInterface;
use Laminas\ServiceManager\Factory\FactoryInterface;
use Psr\Container\ContainerExceptionInterface;
use Psr\Container\NotFoundExceptionInterface;

class ActivityContentHydratorFactory implements FactoryInterface {
    /**
     * @param string $requestedName
     *
     * @throws ContainerExceptionInterface
     * @throws NotFoundExceptionInterface
     *
     * @return ActivityContentHydrator
     */
    public function __invoke(ContainerInterface $container, $requestedName, array $options = null) {
        /** @var ContentTypeStrategyProvider $contentTypeStrategyProvider */
        $contentTypeStrategyProvider = $container->get(ContentTypeStrategyProvider::class);

        return new ActivityContentHydrator($contentTypeStrategyProvider);
    }
}
