<?php

declare(strict_types=1);

namespace Ceilidhboy\WorktreeAutoload;

use Illuminate\Support\ServiceProvider as BaseServiceProvider;

class ServiceProvider extends BaseServiceProvider
{
    public function boot(): void
    {
        if ($this->app->runningInConsole()) {
            $this->commands([
                Commands\WorktreeInitCommand::class,
            ]);

            $this->publishes([
                __DIR__ . '/../stubs/project_autoload.php' => base_path('project_autoload.php'),
            ], 'worktree-autoload');
        }
    }
}
