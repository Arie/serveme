# ClaudeOnRails Context

This project uses ClaudeOnRails with a swarm of specialized agents for Rails development.

## Project Information
- **Rails Version**: 8.1.1
- **Ruby Version**: 4.0.0
- **Project Type**: Full-stack Rails
- **Test Framework**: RSpec (unit/integration tests) + Cucumber (acceptance tests)
- **Turbo/Stimulus**: Enabled
- **Template Engine**: HAML (primary), ERB (secondary)
- **Background Jobs**: Sidekiq workers (not ActiveJob)

## Agent Prompts

The `.claude-on-rails/prompts/` directory contains specialized prompts for different aspects of Rails development:
- **architect.md** - Overall system design and coordination
- **models.md** - ActiveRecord models and database design
- **controllers.md** - Request handling and routing
- **views.md** - Templates and presentation layer
- **services.md** - Business logic and service objects
- **tests.md** - RSpec and Cucumber testing
- **stimulus.md** - JavaScript controllers and Turbo integration
- **jobs.md** - Background job processing
- **api.md** - API endpoints and documentation
- **devops.md** - Deployment and infrastructure

## Development Guidelines

When working on this project:
- Follow Rails conventions and best practices
- Write tests for all new functionality
- Use strong parameters in controllers
- Keep models focused with single responsibilities
- Extract complex business logic to service objects
- Ensure proper database indexing for foreign keys and queries