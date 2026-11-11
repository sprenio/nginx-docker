<?php
$i = 1;
$cfg['Servers'][$i++] = [
  'host' => 'noserver',
  'auth_type' => 'cookie',
  'verbose' =>'Wybierz',
];

$cfg['Servers'][$i++] = [
  'host' => '{db_host_1}',
  'auth_type' => 'config',
  'user' => '{db_user_1}',
  'password' => '{db_password_1}',
  'verbose' =>'{db_verbose_1}',
];
$cfg['Servers'][$i++] = [
  'host' => '{db_host_2}',
  'auth_type' => 'config',
  'user' => '{db_user_2}',
  'password' => '{db_password_2}',
  'verbose' =>'{db_verbose_2}',
];
$cfg['Servers'][$i++] = [
  'host' => '{db_host_3}',
  'auth_type' => 'config',
  'user' => '{db_user_3}',
  'password' => '{db_password_3}',
  'verbose' =>'{db_verbose_3}',
];

