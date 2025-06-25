# typed: false
# frozen_string_literal: true

require 'spec_helper'

RSpec.configure do |config|
  # Specify a root folder where Swagger JSON files are generated
  # NOTE: If you're using the rswag-api to serve API descriptions, you'll need
  # to ensure that it's configured to serve Swagger from the same folder
  config.openapi_root = Rails.root.join('swagger').to_s

  # Define one or more Swagger documents and provide global metadata for each one
  # When you run the 'rswag:specs:swaggerize' rake task, the complete Swagger will
  # be generated at the provided relative path under openapi_root
  # By default, the operations defined in spec files are added to the first
  # document below. You can override this behavior by adding a openapi_spec tag to the
  # the root example_group in your specs, e.g. describe '...', openapi_spec: 'v2/swagger.json'
  config.openapi_specs = {
    'v1/swagger.yaml' => {
      openapi: '3.0.1',
      info: {
        title: 'serveme.tf API',
        description: <<~DESC,
          API for Team Fortress 2 server reservations

          ## Authentication
          Most endpoints require authentication via API key. Users can find their API key in their settings page after creating an account.

          **Important**: API keys are unique per region. You must use the API key from the same region as the server you're calling:
          - EU server requires EU API key from https://serveme.tf
          - NA server requires NA API key from https://na.serveme.tf
          - AU server requires AU API key from https://au.serveme.tf
          - SEA server requires SEA API key from https://sea.serveme.tf

          ## Permission Levels
          - **Public**: No authentication required
          - **User**: Basic API key authentication
          - **Admin**: Admin group membership required
          - **League Admin**: Admin or League Admin group membership required
          - **Trusted API**: Admin or Trusted API group membership required

          ## Groups
          The serveme.tf platform uses a group-based permission system:
          - **Admins**: Full access to all features and admin endpoints
          - **League Admins**: Access to league-related features and searches
          - **Trusted API**: Enhanced API access for automated systems - can manage reservations for any user by providing `steam_uid` parameter
          - **Donators**: Extended reservation times and features
          - **Streamers**: Special streaming-related features
        DESC
        version: 'v1',
        contact: {
          name: 'serveme.tf',
          url: 'https://serveme.tf'
        }
      },
      servers: [
        {
          url: 'https://serveme.tf',
          description: 'Production server (EU)'
        },
        {
          url: 'https://na.serveme.tf',
          description: 'Production server (NA)'
        },
        {
          url: 'https://au.serveme.tf',
          description: 'Production server (AU)'
        },
        {
          url: 'https://sea.serveme.tf',
          description: 'Production server (SEA)'
        },
        {
          url: 'http://localhost:3000',
          description: 'Development server'
        }
      ],
      components: {
        securitySchemes: {
          api_key: {
            type: :apiKey,
            name: 'api_key',
            in: :query,
            description: 'API key for authentication. Users can find their API key in settings.'
          },
          token_auth: {
            type: :apiKey,
            name: 'Authorization',
            in: :header,
            description: 'Legacy token authentication. Use format: "Token token=your_api_key"'
          },
          bearer_token: {
            type: :http,
            scheme: :bearer,
            description: 'Bearer token authentication using API key as token.'
          }
        }
      }
    }
  }

  # Specify the format of the output Swagger file when running 'rswag:specs:swaggerize'.
  # The openapi_specs configuration option has the filename including format in
  # the key, this may want to be changed to avoid putting yaml in json files.
  # Defaults to json. Accepts ':json' and ':yaml'.
  config.openapi_format = :yaml

  # Specify if tests should verify that examples match the response schema
  # This is highly recommended, and the option to disable it will likely be removed in a future version.
  config.openapi_strict_schema_validation = true
end
