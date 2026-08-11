<?php

/**
 * Worktree-aware autoloader wrapper.
 *
 * When vendor/ is symlinked to another worktree's vendor directory,
 * Composer's generated autoload files contain hardcoded paths pointing
 * to whichever worktree last ran composer dump-autoload. This wrapper
 * detects the symlink and corrects project-namespace PSR-4 prefix dirs
 * and the classmap at runtime, so that App\, Tests\, and Database\
 * namespaces resolve to the current worktree rather than the one that
 * generated the autoload files.
 *
 * When vendor/ is NOT a symlink (standard install, production, colleagues),
 * this file is a transparent passthrough — it loads Composer's autoloader
 * and returns it unchanged.
 *
 * This file is gitignored. Each worktree has its own copy, created by
 * php artisan worktree:init or setup-worktree.
 */

$projectRoot = __DIR__;
$loader = require $projectRoot . '/vendor/autoload.php';

// No symlink? Standard install — nothing to fix
if (!is_link($projectRoot . '/vendor')) {
    return $loader;
}

$realVendorDir = realpath($projectRoot . '/vendor');

// Discover the base path the autoload files were generated with.
// App\ always maps to $baseDir . '/app' in the generated files, so
// dirname() of the first App\ directory gives us the generated base.
$prefixes = $loader->getPrefixesPsr4();
$appDirs = $prefixes['App\\'] ?? [];
if (empty($appDirs)) {
    return $loader; // Can't determine generated base, bail
}

$generatedBase = dirname($appDirs[0]);

// Fix PSR-4 prefixes
foreach ($prefixes as $namespace => $dirs) {
    $fixed = [];
    foreach ($dirs as $dir) {
        // Vendor path — leave it (always correct through the symlink)
        if (str_starts_with($dir, $realVendorDir . '/')) {
            $fixed[] = $dir;
        }
        // Already matches this worktree — leave it
        elseif (str_starts_with($dir, $projectRoot . '/')) {
            $fixed[] = $dir;
        }
        // Stale project path — replace generated base with CWD
        elseif (str_starts_with($dir, $generatedBase)) {
            $fixed[] = str_replace($generatedBase, $projectRoot, $dir);
        }
        // Unknown — leave as-is (shouldn't happen)
        else {
            $fixed[] = $dir;
        }
    }
    $loader->setPsr4($namespace, $fixed);
}

// Fix classmap — needs reflection because $classMap is private with no setter
$classMap = $loader->getClassMap();
if (!empty($classMap)) {
    $fixedMap = [];
    foreach ($classMap as $class => $path) {
        if (str_starts_with($path, $realVendorDir . '/')) {
            $fixedMap[$class] = $path;            // Keep vendor paths
        } elseif (str_starts_with($path, $projectRoot . '/')) {
            $fixedMap[$class] = $path;             // Already correct
        } elseif (str_starts_with($path, $generatedBase)) {
            $fixedMap[$class] = str_replace($generatedBase, $projectRoot, $path);
        } else {
            $fixedMap[$class] = $path;             // Unknown, leave as-is
        }
    }

    $ref = new ReflectionProperty($loader, 'classMap');
    $ref->setAccessible(true);
    $ref->setValue($loader, $fixedMap);
}

return $loader;
