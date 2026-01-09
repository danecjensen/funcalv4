# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Rails 7.1.4 SaaS starter template with PostgreSQL, Hotwire (Turbo + Stimulus), Bootstrap 5, Devise authentication with OmniAuth (Facebook, GitHub, Twitter), Pundit authorization, Sidekiq background jobs, and Heroku deployment.

## Common Commands

### Development
```bash
bin/dev                    # Start dev server (Foreman: Rails + JS + CSS watchers)
bin/rails server           # Rails server only (port 3000)
```

### Testing
```bash
bin/rails test             # Run all tests
bin/rails test test/models/user_test.rb           # Run single test file
bin/rails test test/models/user_test.rb:10        # Run specific test at line
bin/rails test:system      # Run system/browser tests
```

### Database
```bash
bin/rails db:prepare       # Create and migrate database
bin/rails db:migrate       # Run pending migrations
bin/rails db:reset         # Drop, recreate, seed database
```

### Assets
```bash
yarn build                 # Bundle JS with esbuild
yarn run build:css         # Compile and prefix CSS
```

## Architecture

### Authentication & Authorization
- **Devise** handles user auth with OmniAuth for social login
- **Pundit** policies in `app/policies/` control authorization
- **Pretender** enables admin user impersonation
- User model: `app/models/user.rb` with `admin?` method for admin access

### Admin Access
Routes requiring `admin?` (defined in `config/routes.rb`):
- `/sidekiq` - Sidekiq dashboard
- `/madmin/impersonates` - User impersonation

### Frontend Stack
- **Turbo** for SPA-like navigation without full reloads
- **Stimulus** controllers in `app/javascript/controllers/`
- **Bootstrap 5** with SCSS in `app/assets/stylesheets/application.bootstrap.scss`
- **Trix** for rich text editing

### Background Jobs
- **Sidekiq** as ActiveJob adapter
- Jobs go in `app/jobs/`
- Production worker defined in `Procfile`: `worker: bundle exec sidekiq`

### Notifications
- **Noticed** gem for in-app notifications
- `resources :notifications, only: [:index]` route available

### Key Models
- `User` - Devise authentication, has_many :services
- `Service` - OAuth provider connections (belongs_to :user)
- `Announcement` - System-wide announcements

## Build Pipeline

**JS**: esbuild bundles `app/javascript/application.js` → `app/assets/builds/`
**CSS**: Sass compiles `application.bootstrap.scss` → PostCSS autoprefixer → `app/assets/builds/`

Watchers run via Foreman when using `bin/dev`.
