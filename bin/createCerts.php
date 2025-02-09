#!/usr/bin/php
<?php

function exitWithError(string $error = ''): void
{
    $error = trim($error);
    if (strlen($error) > 0) {
        fwrite(STDERR, $error . PHP_EOL);
    }
    exit(1);
}

function execCommand(string $command, $verbose = false, &$output = []): bool
{
    if ($verbose) {
        echo $command . PHP_EOL;
    }
    $res = exec($command, $output, $resultCode);
    if ($verbose) {
        echo implode(PHP_EOL, $output) . PHP_EOL;
    }
    return (false !== $res && empty($resultCode));
}


function getCertInfo(string $domainsStr): array
{
    echo 'checking for certificate for domain(s) ' . $domainsStr . ' ...' . PHP_EOL;
    $certificates = $currentCertificate = [];
    execCommand('certbot certificates', false, $output);
    foreach ($output as $i => $line) {
        $line = trim($line);
        $items = array_map('trim', explode(':', $line, 2));
        if (!isset($items[1]) || !strlen($items[1])) {
            continue;
        }
        switch ($items[0]) {
            case 'Certificate Name':
                if (!empty($currentCertificate['Domains'])) {
                    $certDomains = $currentCertificate['Domains'];
                    $certificates[$certDomains] = $currentCertificate;
                }
                $currentCertificate = [];
            // no break;
            default:
                $currentCertificate[$items[0]] = $items[1];
                break;
        }
    }
    if (!empty($currentCertificate['Domains'])) {
        $certDomains = $currentCertificate['Domains'];
        $certificates[$certDomains] = $currentCertificate;
    }
    return $certificates[$domainsStr] ?? [];

}

function getOptionDomainsInfo(string $option): array
{
    $domains = explode(',', $option);
    $mainDomain = array_shift($domains);
    sort($domains);
    array_unshift($domains, $mainDomain);

    return [
      'mainDomain' => $mainDomain,
      'domainOption' => implode(',', $domains),
      'domainStr' => implode(' ', $domains),
    ];
}

if (posix_getuid() !== 0) {
    exitWithError('Permission denied: This script requires root privileges.' . PHP_EOL . 'Please run it with "sudo" or as the root user.');
}
[$scriptPath] = get_included_files();

$appDir = dirname($scriptPath, 2);
$envFile = $appDir . DIRECTORY_SEPARATOR . '.env';

$envVars = [];
if (file_exists($envFile)) {
    $lines = file($envFile, FILE_IGNORE_NEW_LINES);
    foreach ($lines as $line) {
        preg_match('/^\\s*([^#\\s]\\S*)\s*=(.*)$/', $line, $matches);
        if (!empty($matches[1])) {
            $name = $matches[1];
            $value = trim($matches[2]);
            $envVars[$name] = preg_replace('/^([\'"])(.*)\\1$/', '$2', $value);
        }
    }
} else {
    echo '"env file  ' . $envFile . ' doesn\'t exist, using default values' . PHP_EOL;
}

if (empty($envVars['CERT_CHALLENGE_DIR'])) {
    $challengeDir = $appDir . DIRECTORY_SEPARATOR . 'cert_challenge';
    echo 'CERT_CHALLENGE_DIR is not set, setting default value: ' . $challengeDir . PHP_EOL;
} else {
    $challengeDir = $envVars['CERT_CHALLENGE_DIR'];
}
if (!is_dir($challengeDir)) {
    exitWithError('CERT_CHALLENGE_DIR ' . $challengeDir . ' is not a directory');
}
if (empty($envVars['SSL_CERTIFICATES_DIR'])) {
    $sslDir = $appDir . DIRECTORY_SEPARATOR . 'ssl_certificates';
    echo 'SSL_CERTIFICATES_DIR is not set, setting default value: ' . $sslDir . PHP_EOL;
} else {
    $sslDir = $envVars['SSL_CERTIFICATES_DIR'];
}
if (!is_dir($sslDir)) {
    exitWithError('SSL_CERTIFICATES_DIR ' . $sslDir . ' is not a directory');
}

$options = getopt('d:a:');
if (empty($options['d']) || empty($options['a'])) {
    $err = implode(PHP_EOL, [
      'usage: ' . $scriptPath . ' <options>',
      '  options:',
      '    -d    coma separated list of domains',
      '    -a    email address for notifications',
    ]);
    exitWithError($err);
}

$domainParamInfo = getOptionDomainsInfo($options['d']);

$mainDomain = $domainParamInfo['mainDomain'];
$info = getCertInfo($domainParamInfo['domainStr']);

if (empty($info)) {
    echo 'certificate for ' . $options['d'] . ' doesn\'t exist. Creating a certificate ...' . PHP_EOL;
    execCommand('/usr/bin/certbot certonly -n --agree-tos --webroot -w ' . escapeshellarg($challengeDir) . ' -d ' . escapeshellarg($domainParamInfo['domainOption']) . ' -m ' . escapeshellarg($options['a']), false, $output);
    $info = getCertInfo($domainParamInfo['domainStr']);
} else {
    echo 'certificate for ' . $options['d'] . ' already exist';
}
if (empty($info['Certificate Path'])) {
    exitWithError('Certificate Path for ' . $options['d'] . ' is not set.');
}
if (empty($info['Private Key Path'])) {
    exitWithError('Private Key Path for ' . $options['d'] . ' is not set.');
}

print_r($info);

$sslDomainDir = $sslDir . DIRECTORY_SEPARATOR . $mainDomain;
if (!is_dir($sslDomainDir)) {
    mkdir($sslDomainDir, 0755, true) || exitWithError('Cannot create domain directory ' . $sslDomainDir);
}
$certPath = $sslDomainDir . DIRECTORY_SEPARATOR . 'fullchain.pem';
$keyPath = $sslDomainDir . DIRECTORY_SEPARATOR . 'privkey.pem';
if (is_link($certPath)) {
    unlink($certPath);
} else if (file_exists($certPath)) {
    rename($certPath, $certPath . '.bak');
}

$targetCertPath = preg_replace('/^\\W*archive/','/etc/letsencrypt/archive/', readlink($info['Certificate Path']));
$targetKeyPath = preg_replace('/^\\W*archive/','/etc/letsencrypt/archive/', readlink($info['Private Key Path']));

symlink($targetCertPath, $certPath);
if (is_link($keyPath)) {
    unlink($keyPath);
} else if (file_exists($keyPath)) {
    rename($keyPath, $keyPath . '.bak');
}
symlink($targetKeyPath, $keyPath);
echo PHP_EOL;
