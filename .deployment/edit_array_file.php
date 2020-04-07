<?php
function setArray(&$array, $keys, $value) {
    $keys = explode(".", $keys);
    $current = &$array;
    foreach($keys as $key) {
        $current = &$current[$key];
    }
    $current = $value;
}
$file = __DIR__.'/../'.$argv[1];
$array = require_once $file;
setArray($array, $argv[2], $argv[3]);
file_put_contents($file, '<?php return ' . var_export($array, true) . ';');
