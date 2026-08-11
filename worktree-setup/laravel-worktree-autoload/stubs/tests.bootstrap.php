<?php

/**
 * PHPUnit bootstrap — worktree-aware autoloader loading.
 *
 * Checks for a local project_autoload.php (which corrects paths when
 * vendor/ is symlinked to another worktree) and falls back to the
 * standard Composer autoloader when no symlink is present.
 *
 * This allows phpunit.xml to work unchanged across production, CI,
 * colleagues' machines (no project_autoload.php), and worktree-based
 * development setups (project_autoload.php present).
 */

$autoloadPath = __DIR__ . '/../vendor/autoload.php';

if (file_exists(__DIR__ . '/../project_autoload.php')) {
    $autoloadPath = __DIR__ . '/../project_autoload.php';
}

return require $autoloadPath;
