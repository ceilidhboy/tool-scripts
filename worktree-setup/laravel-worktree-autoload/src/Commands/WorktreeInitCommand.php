<?php

declare(strict_types=1);

namespace Ceilidhboy\WorktreeAutoload\Commands;

use Illuminate\Console\Command;
use Illuminate\Filesystem\Filesystem;
use Illuminate\Support\Str;

class WorktreeInitCommand extends Command
{
    protected $signature = 'worktree:init
        {--force : Overwrite existing files without checking}';

    protected $description = 'Bootstrap the project for symlinked-vendor worktree support';

    /**
     * All patching operations are idempotent — they check whether the
     * change has already been applied before modifying anything.
     * Safe to run repeatedly on the same project.
     */
    public function handle(Filesystem $filesystem): int
    {
        $this->components->info('Bootstrapping worktree autoload support...');

        $patched = 0;

        // 1. Patch public/index.php
        if ($this->patchIndexPhp($filesystem)) {
            $patched++;
        }

        // 2. Patch artisan
        if ($this->patchArtisan($filesystem)) {
            $patched++;
        }

        // 3. Create tests/bootstrap.php
        if ($this->createTestsBootstrap($filesystem)) {
            $patched++;
        }

        // 4. Patch phpunit.xml
        if ($this->patchPhpunitXml($filesystem)) {
            $patched++;
        }

        // 5. Update .gitignore
        if ($this->updateGitignore($filesystem)) {
            $patched++;
        }

        // 6. Publish project_autoload.php (gitignored, always refreshed)
        $this->publishProjectAutoload($filesystem);

        if ($patched > 0) {
            $this->components->info("Made {$patched} change(s). project_autoload.php is up to date.");
        } else {
            $this->components->info('Already up to date. project_autoload.php refreshed.');
        }

        return self::SUCCESS;
    }

    /**
     * Replace the require vendor/autoload.php line in public/index.php
     * with the conditional block that checks for project_autoload.php.
     */
    private function patchIndexPhp(Filesystem $filesystem): bool
    {
        $path = base_path('public/index.php');

        if (!$filesystem->exists($path)) {
            $this->components->warn('public/index.php not found — skipping');

            return false;
        }

        $content = $filesystem->get($path);

        // Already patched?
        if (str_contains($content, 'project_autoload.php')) {
            return false;
        }

        $search = "require __DIR__ . '/../vendor/autoload.php';";
        $replace = <<<'PHP'
$projectAutoload = __DIR__ . '/../project_autoload.php';
$autoload = file_exists($projectAutoload)
    ? $projectAutoload
    : __DIR__ . '/../vendor/autoload.php';
$loader = require $autoload;
PHP;

        if (!str_contains($content, $search)) {
            $this->components->warn('public/index.php: expected line not found — skipping');

            return false;
        }

        $filesystem->put($path, str_replace($search, $replace, $content));
        $this->components->info('Patched public/index.php');

        return true;
    }

    /**
     * Replace the require vendor/autoload.php line in artisan.
     */
    private function patchArtisan(Filesystem $filesystem): bool
    {
        $path = base_path('artisan');

        if (!$filesystem->exists($path)) {
            $this->components->warn('artisan not found — skipping');

            return false;
        }

        $content = $filesystem->get($path);

        if (str_contains($content, 'project_autoload.php')) {
            return false;
        }

        $search = "require __DIR__.'/vendor/autoload.php';";
        $replace = <<<'PHP'
$projectAutoload = __DIR__.'/project_autoload.php';
$autoload = file_exists($projectAutoload)
    ? $projectAutoload
    : __DIR__.'/vendor/autoload.php';
$loader = require $autoload;
PHP;

        if (!str_contains($content, $search)) {
            $this->components->warn('artisan: expected line not found — skipping');

            return false;
        }

        $filesystem->put($path, str_replace($search, $replace, $content));
        $this->components->info('Patched artisan');

        return true;
    }

    /**
     * Create tests/bootstrap.php from the stub if it doesn't exist.
     */
    private function createTestsBootstrap(Filesystem $filesystem): bool
    {
        $target = base_path('tests/bootstrap.php');

        if ($filesystem->exists($target) && !$this->option('force')) {
            return false;
        }

        $stub = __DIR__ . '/../../stubs/tests.bootstrap.php';

        if (!$filesystem->exists($stub)) {
            $this->components->warn('tests/bootstrap.php stub not found — skipping');

            return false;
        }

        $filesystem->copy($stub, $target);
        $this->components->info('Created tests/bootstrap.php');

        return true;
    }

    /**
     * Change phpunit.xml bootstrap from vendor/autoload.php to tests/bootstrap.php.
     */
    private function patchPhpunitXml(Filesystem $filesystem): bool
    {
        $path = base_path('phpunit.xml');

        if (!$filesystem->exists($path)) {
            $this->components->warn('phpunit.xml not found — skipping');

            return false;
        }

        $content = $filesystem->get($path);

        if (str_contains($content, 'tests/bootstrap.php')) {
            return false;
        }

        $search = 'bootstrap="vendor/autoload.php"';
        $replace = 'bootstrap="tests/bootstrap.php"';

        if (!str_contains($content, $search)) {
            $this->components->warn('phpunit.xml: expected bootstrap attribute not found — skipping');

            return false;
        }

        $filesystem->put($path, str_replace($search, $replace, $content));
        $this->components->info('Patched phpunit.xml');

        return true;
    }

    /**
     * Append /project_autoload.php to .gitignore if not already present.
     */
    private function updateGitignore(Filesystem $filesystem): bool
    {
        $path = base_path('.gitignore');

        if (!$filesystem->exists($path)) {
            $this->components->warn('.gitignore not found — skipping');

            return false;
        }

        $content = $filesystem->get($path);

        if (str_contains($content, 'project_autoload.php')) {
            return false;
        }

        $filesystem->append($path, "\n/project_autoload.php\n");
        $this->components->info('Updated .gitignore');

        return true;
    }

    /**
     * Publish project_autoload.php to the project root.
     * This file is gitignored — each worktree gets its own copy.
     */
    private function publishProjectAutoload(Filesystem $filesystem): void
    {
        $target = base_path('project_autoload.php');
        $stub = __DIR__ . '/../../stubs/project_autoload.php';

        if (!$filesystem->exists($stub)) {
            $this->components->warn('project_autoload.php stub not found — skipping');

            return;
        }

        $filesystem->copy($stub, $target);
        $this->components->info('Published project_autoload.php');
    }
}
