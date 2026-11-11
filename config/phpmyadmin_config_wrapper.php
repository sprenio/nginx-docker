<?php
$local_config = __DIR__ . '/local/config.inc.php';
if (is_readable($local_config)) {
    include_once $local_config;
}
