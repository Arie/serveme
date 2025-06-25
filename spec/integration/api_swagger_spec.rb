# typed: false
# frozen_string_literal: true

require 'spec_helper'
require 'swagger_helper'

RSpec.describe 'serveme.tf API', type: :request do
  let(:user) { create(:user).tap { |u| u.generate_api_key! } }
  let(:admin_user) { create(:user).tap { |u| u.groups << Group.admin_group; u.generate_api_key! } }
  let(:api_key) { user.api_key }
  let(:admin_api_key) { admin_user.api_key }

  # Users API
  path '/api/users/{id}' do
    get 'Get user information' do
      tags 'Users'
      parameter name: :id, in: :path, type: :integer, description: 'User ID (Steam UID)'
      parameter name: :api_key, in: :query, type: :string, required: false, description: 'API key for authentication'
      security [ { api_key: [] }, { token_auth: [] }, { bearer_token: [] } ]

      produces 'application/json'

      response '200', 'User found' do
        schema type: :object,
               properties: {
                 user: {
                   type: :object,
                   properties: {
                     id: { type: :integer },
                     uid: { type: :string },
                     nickname: { type: :string },
                     name: { type: :string },
                     donator: { type: :boolean },
                     donator_until: { type: :string, nullable: true },
                     reservations_made: { type: :integer },
                     total_reservation_seconds: { type: :integer }
                   }
                 }
               }

        let(:id) { user.uid }
        let(:api_key) { user.api_key }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['user']['uid']).to eq(user.uid)
          expect(data['user']['nickname']).to eq(user.nickname)
        end
      end

      response '401', 'Unauthorized' do
        let(:id) { user.uid }
        let(:api_key) { 'invalid' }

        run_test!
      end

      response '404', 'User not found' do
        let(:id) { 999999 }
        let(:api_key) { user.api_key }

        run_test!
      end
    end
  end

  # Maps API (Public)
  path '/api/maps' do
    get 'List available maps' do
      tags 'Maps'
      produces 'application/json'

      response '200', 'List of maps' do
        schema type: :object,
               properties: {
                 maps: {
                   type: :array,
                   items: { type: :string }
                 }
               }

        run_test!
      end
    end
  end

  # Servers API
  path '/api/servers' do
    get 'List available servers' do
      tags 'Servers'
      parameter name: :api_key, in: :query, type: :string, required: false, description: 'API key for authentication'
      security [ { api_key: [] }, { token_auth: [] }, { bearer_token: [] } ]

      produces 'application/json'

      response '200', 'List of servers' do
        schema type: :object,
               properties: {
                 servers: {
                   type: :array,
                   items: {
                     type: :object,
                     properties: {
                       id: { type: :integer },
                       name: { type: :string },
                       location: {
                         type: :object,
                         properties: {
                           id: { type: :integer },
                           name: { type: :string },
                           flag: { type: :string }
                         }
                       }
                     }
                   }
                 }
               }

        let(:api_key) { user.api_key }

        run_test!
      end

      response '401', 'Unauthorized' do
        let(:api_key) { 'invalid' }

        run_test!
      end
    end
  end

  # Reservations API
  path '/api/reservations/new' do
    get 'Get prefilled reservation template (Step 1)' do
      tags 'Reservations'
      parameter name: :api_key, in: :query, type: :string, required: false, description: 'API key for authentication'
      security [ { api_key: [] }, { token_auth: [] }, { bearer_token: [] } ]

      produces 'application/json'

      response '200', 'Prefilled reservation template' do
        schema type: :object,
               properties: {
                 reservation: {
                   type: :object,
                   properties: {
                     starts_at: { type: :string, format: 'date-time' },
                     ends_at: { type: :string, format: 'date-time' }
                   }
                 },
                 actions: {
                   type: :object,
                   properties: {
                     find_servers: { type: :string }
                   }
                 }
               }

        let(:api_key) { user.api_key }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['reservation']).to have_key('starts_at')
          expect(data['reservation']).to have_key('ends_at')
          expect(data['actions']).to have_key('find_servers')
        end
      end

      response '401', 'Unauthorized' do
        let(:api_key) { 'invalid' }

        run_test!
      end
    end
  end

  path '/api/reservations/find_servers' do
    post 'Find available servers for reservation (Step 2)' do
      tags 'Reservations'
      parameter name: :api_key, in: :query, type: :string, required: false, description: 'API key for authentication'
      parameter name: :steam_uid, in: :query, type: :string, required: false, description: 'Steam UID'
      security [ { api_key: [] }, { token_auth: [] }, { bearer_token: [] } ]

      consumes 'application/json'
      produces 'application/json'

      parameter name: :reservation, in: :body, schema: {
        type: :object,
        properties: {
          reservation: {
            type: :object,
            properties: {
              starts_at: { type: :string, format: 'date-time' },
              ends_at: { type: :string, format: 'date-time' }
            },
            required: [ 'starts_at', 'ends_at' ]
          }
        }
      }

      response '200', 'Available servers with reservation template' do
        schema type: :object,
               properties: {
                 reservation: {
                   type: :object,
                   properties: {
                     status: { type: :string },
                     starts_at: { type: :string, format: 'date-time' },
                     ends_at: { type: :string, format: 'date-time' },
                     server_id: { type: :integer, nullable: true },
                     password: { type: :string, nullable: true },
                     rcon: { type: :string, nullable: true },
                     first_map: { type: :string, nullable: true },
                     tv_password: { type: :string },
                     tv_relaypassword: { type: :string },
                     tv_port: { type: :integer, nullable: true },
                     server_config_id: { type: :integer, nullable: true },
                     whitelist_id: { type: :integer, nullable: true },
                     custom_whitelist_id: { type: :integer, nullable: true },
                     auto_end: { type: :boolean },
                     enable_plugins: { type: :boolean },
                     enable_demos_tf: { type: :boolean },
                     sdr_ip: { type: :string, nullable: true },
                     sdr_port: { type: :integer, nullable: true },
                     sdr_tv_port: { type: :integer, nullable: true },
                     sdr_final: { type: :boolean },
                     disable_democheck: { type: :boolean }
                   }
                 },
                 servers: {
                   type: :array,
                   items: {
                     type: :object,
                     properties: {
                       id: { type: :integer },
                       name: { type: :string },
                       location: {
                         type: :object,
                         properties: {
                           id: { type: :integer },
                           name: { type: :string },
                           flag: { type: :string }
                         }
                       }
                     }
                   }
                 },
                 server_configs: {
                   type: :array,
                   items: {
                     type: :object,
                     properties: {
                       id: { type: :integer },
                       file: { type: :string }
                     }
                   }
                 },
                 whitelists: {
                   type: :array,
                   items: {
                     type: :object,
                     properties: {
                       id: { type: :integer },
                       file: { type: :string }
                     }
                   }
                 },
                 actions: {
                   type: :object,
                   properties: {
                     create: { type: :string }
                   }
                 }
               }

        let(:api_key) { user.api_key }
        let(:reservation) do
          {
            reservation: {
              starts_at: (Time.current + 1.hour).iso8601,
              ends_at: (Time.current + 3.hours).iso8601
            }
          }
        end

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data).to have_key('reservation')
          expect(data).to have_key('servers')
          expect(data).to have_key('actions')
          expect(data['actions']).to have_key('create')
        end
      end

      response '401', 'Unauthorized' do
        let(:api_key) { 'invalid' }
        let(:reservation) do
          {
            reservation: {
              starts_at: (Time.current + 1.hour).iso8601,
              ends_at: (Time.current + 3.hours).iso8601
            }
          }
        end

        run_test!
      end
    end
  end

  path '/api/reservations' do
    get 'List reservations' do
      tags 'Reservations'
      parameter name: :api_key, in: :query, type: :string, required: false, description: 'API key for authentication'
      parameter name: :steam_uid, in: :query, type: :string, required: false, description: 'Steam UID to filter reservations'
      parameter name: :limit, in: :query, type: :integer, required: false, description: 'Limit number of results'
      parameter name: :offset, in: :query, type: :integer, required: false, description: 'Offset for pagination'
      security [ { api_key: [] }, { token_auth: [] }, { bearer_token: [] } ]

      produces 'application/json'

      response '200', 'List of reservations' do
        schema type: :object,
               properties: {
                 reservations: {
                   type: :array,
                   items: {
                     type: :object,
                     properties: {
                       id: { type: :integer },
                       server_id: { type: :integer },
                       user_id: { type: :integer },
                       starts_at: { type: :string, format: 'date-time' },
                       ends_at: { type: :string, format: 'date-time' }
                     }
                   }
                 }
               }

        let(:api_key) { user.api_key }

        run_test!
      end

      response '401', 'Unauthorized' do
        let(:api_key) { 'invalid' }

        run_test!
      end
    end

    post 'Create new reservation (Step 3)' do
      tags 'Reservations'
      parameter name: :api_key, in: :query, type: :string, required: false, description: 'API key for authentication'
      parameter name: :steam_uid, in: :query, type: :string, required: false, description: 'Steam UID (for Trusted API users)'
      security [ { api_key: [] }, { token_auth: [] }, { bearer_token: [] } ]

      consumes 'application/json'
      produces 'application/json'

      parameter name: :reservation, in: :body, schema: {
        type: :object,
        properties: {
          reservation: {
            type: :object,
            properties: {
              starts_at: { type: :string, format: 'date-time' },
              ends_at: { type: :string, format: 'date-time' },
              server_id: { type: :integer },
              password: { type: :string },
              rcon: { type: :string },
              tv_password: { type: :string },
              tv_relaypassword: { type: :string },
              first_map: { type: :string },
              server_config_id: { type: :integer },
              whitelist_id: { type: :integer },
              custom_whitelist_id: { type: :integer },
              auto_end: { type: :boolean }
            },
            required: [ 'starts_at', 'ends_at', 'server_id' ]
          }
        }
      }

      response '200', 'Reservation created successfully' do
        schema type: :object,
               properties: {
                 reservation: {
                   type: :object,
                   properties: {
                     id: { type: :integer },
                     server_id: { type: :integer },
                     starts_at: { type: :string, format: 'date-time' },
                     ends_at: { type: :string, format: 'date-time' },
                     password: { type: :string },
                     rcon: { type: :string },
                     tv_password: { type: :string },
                     tv_relaypassword: { type: :string },
                     logsecret: { type: :string },
                     status: { type: :string },
                     first_map: { type: :string, nullable: true },
                     tv_port: { type: :integer },
                     server_config_id: { type: :integer, nullable: true },
                     whitelist_id: { type: :integer, nullable: true },
                     custom_whitelist_id: { type: :integer, nullable: true },
                     auto_end: { type: :boolean },
                     enable_plugins: { type: :boolean },
                     enable_demos_tf: { type: :boolean },
                     sdr_ip: { type: :string, nullable: true },
                     sdr_port: { type: :integer, nullable: true },
                     sdr_tv_port: { type: :integer, nullable: true },
                     sdr_final: { type: :boolean },
                     disable_democheck: { type: :boolean },
                     last_number_of_players: { type: :integer },
                     inactive_minute_counter: { type: :integer },
                     start_instantly: { type: :boolean },
                     end_instantly: { type: :boolean },
                     provisioned: { type: :boolean },
                     ended: { type: :boolean },
                     steam_uid: { type: :string },
                     server: {
                       type: :object,
                       properties: {
                         id: { type: :integer },
                         name: { type: :string },
                         flag: { type: :string },
                         ip: { type: :string },
                         port: { type: :string },
                         ip_and_port: { type: :string },
                         sdr: { type: :boolean },
                         latitude: { type: :number },
                         longitude: { type: :number }
                       }
                     }
                   }
                 },
                 actions: {
                   type: :object,
                   properties: {
                     patch: { type: :string },
                     delete: { type: :string }
                   }
                 }
               }

        let(:api_key) { user.api_key }
        let(:server) { create(:server, location: create(:location)) }
        let(:reservation) do
          {
            reservation: {
              starts_at: (Time.current + 1.hour).iso8601,
              ends_at: (Time.current + 3.hours).iso8601,
              server_id: server.id,
              password: 'testpass',
              rcon: 'testrcon'
            }
          }
        end

        before do
          # Mock the ReservationWorker to prevent actual server provisioning
          allow(ReservationWorker).to receive(:perform_async)
        end

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['reservation']).to have_key('id')
          expect(data['reservation']['server_id']).to eq(server.id)
          expect(data['reservation']['password']).to eq('testpass')
          expect(data['reservation']['rcon']).to eq('testrcon')
        end
      end

      response '422', 'Invalid reservation data' do
        let(:api_key) { user.api_key }
        let(:reservation) do
          {
            reservation: {
              # Missing required fields like starts_at, ends_at, server_id
            }
          }
        end

        run_test!
      end

      response '401', 'Unauthorized' do
        let(:api_key) { 'invalid' }
        let(:reservation) do
          {
            reservation: {
              starts_at: (Time.current + 1.hour).iso8601,
              ends_at: (Time.current + 3.hours).iso8601,
              server_id: 1
            }
          }
        end

        run_test!
      end

      response '422', 'Invalid JSON' do
        let(:api_key) { user.api_key }
        let(:reservation) { { invalid_field: 'value' } }

        run_test!
      end
    end
  end

  path '/api/reservations/{id}' do
    get 'Get reservation details (Step 5)' do
      tags 'Reservations'
      parameter name: :id, in: :path, type: :integer, description: 'Reservation ID'
      parameter name: :api_key, in: :query, type: :string, required: false, description: 'API key for authentication'
      security [ { api_key: [] }, { token_auth: [] }, { bearer_token: [] } ]

      produces 'application/json'

      response '200', 'Reservation details' do
        schema type: :object,
               properties: {
                 reservation: {
                   type: :object,
                   properties: {
                     id: { type: :integer },
                     server_id: { type: :integer },
                     starts_at: { type: :string, format: 'date-time' },
                     ends_at: { type: :string, format: 'date-time' },
                     password: { type: :string },
                     rcon: { type: :string },
                     tv_password: { type: :string },
                     tv_relaypassword: { type: :string },
                     status: { type: :string },
                     first_map: { type: :string, nullable: true },
                     tv_port: { type: :integer },
                     server_config_id: { type: :integer, nullable: true },
                     whitelist_id: { type: :integer, nullable: true },
                     custom_whitelist_id: { type: :integer, nullable: true },
                     auto_end: { type: :boolean },
                     enable_plugins: { type: :boolean },
                     enable_demos_tf: { type: :boolean },
                     sdr_ip: { type: :string, nullable: true },
                     sdr_port: { type: :integer, nullable: true },
                     sdr_tv_port: { type: :integer, nullable: true },
                     sdr_final: { type: :boolean },
                     disable_democheck: { type: :boolean },
                     last_number_of_players: { type: :integer },
                     inactive_minute_counter: { type: :integer },
                     logsecret: { type: :string },
                     start_instantly: { type: :boolean },
                     end_instantly: { type: :boolean },
                     provisioned: { type: :boolean },
                     ended: { type: :boolean },
                     steam_uid: { type: :string },
                     server: {
                       type: :object,
                       properties: {
                         id: { type: :integer },
                         name: { type: :string },
                         flag: { type: :string },
                         ip: { type: :string },
                         port: { type: :string },
                         ip_and_port: { type: :string },
                         sdr: { type: :boolean },
                         latitude: { type: :number },
                         longitude: { type: :number }
                       }
                     }
                   }
                 },
                 actions: {
                   type: :object,
                   properties: {
                     patch: { type: :string },
                     delete: { type: :string }
                   }
                 }
               }

        let(:api_key) { user.api_key }
        let(:reservation_record) { create(:reservation, user: user) }
        let(:id) { reservation_record.id }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['reservation']['id']).to eq(reservation_record.id)
        end
      end

      response '401', 'Unauthorized' do
        let(:api_key) { 'invalid' }
        let(:id) { 1 }

        run_test!
      end

      response '404', 'Reservation not found' do
        let(:api_key) { user.api_key }
        let(:id) { -1 }

        run_test!
      end
    end

    patch 'Update reservation (Step 4)' do
      tags 'Reservations'
      parameter name: :id, in: :path, type: :integer, description: 'Reservation ID'
      parameter name: :api_key, in: :query, type: :string, required: false, description: 'API key for authentication'
      security [ { api_key: [] }, { token_auth: [] }, { bearer_token: [] } ]

      consumes 'application/json'
      produces 'application/json'

      parameter name: :reservation, in: :body, schema: {
        type: :object,
        properties: {
          reservation: {
            type: :object,
            properties: {
              ends_at: { type: :string, format: 'date-time' },
              password: { type: :string },
              rcon: { type: :string },
              tv_password: { type: :string },
              tv_relaypassword: { type: :string },
              first_map: { type: :string },
              server_config_id: { type: :integer },
              whitelist_id: { type: :integer },
              custom_whitelist_id: { type: :integer }
            }
          }
        }
      }

      response '200', 'Reservation updated successfully' do
        schema type: :object,
               properties: {
                 reservation: {
                   type: :object,
                   properties: {
                     id: { type: :integer },
                     server_id: { type: :integer },
                     starts_at: { type: :string, format: 'date-time' },
                     ends_at: { type: :string, format: 'date-time' },
                     password: { type: :string },
                     rcon: { type: :string },
                     tv_password: { type: :string },
                     tv_relaypassword: { type: :string },
                     status: { type: :string },
                     first_map: { type: :string, nullable: true },
                     tv_port: { type: :integer },
                     server_config_id: { type: :integer, nullable: true },
                     whitelist_id: { type: :integer, nullable: true },
                     custom_whitelist_id: { type: :integer, nullable: true },
                     auto_end: { type: :boolean },
                     enable_plugins: { type: :boolean },
                     enable_demos_tf: { type: :boolean },
                     sdr_ip: { type: :string, nullable: true },
                     sdr_port: { type: :integer, nullable: true },
                     sdr_tv_port: { type: :integer, nullable: true },
                     sdr_final: { type: :boolean },
                     disable_democheck: { type: :boolean },
                     last_number_of_players: { type: :integer },
                     inactive_minute_counter: { type: :integer },
                     logsecret: { type: :string },
                     start_instantly: { type: :boolean },
                     end_instantly: { type: :boolean },
                     provisioned: { type: :boolean },
                     ended: { type: :boolean },
                     steam_uid: { type: :string },
                     server: {
                       type: :object,
                       properties: {
                         id: { type: :integer },
                         name: { type: :string },
                         flag: { type: :string },
                         ip: { type: :string },
                         port: { type: :string },
                         ip_and_port: { type: :string },
                         sdr: { type: :boolean },
                         latitude: { type: :number },
                         longitude: { type: :number }
                       }
                     }
                   }
                 },
                 actions: {
                   type: :object,
                   properties: {
                     patch: { type: :string },
                     delete: { type: :string }
                   }
                 }
               }

        let(:api_key) { user.api_key }
        let(:reservation_record) { create(:reservation, user: user, ends_at: 1.hour.from_now) }
        let(:id) { reservation_record.id }
        let(:new_ends_at) { 90.minutes.from_now.change(usec: 0) }
        let(:reservation) do
          {
            reservation: {
              ends_at: new_ends_at.iso8601,
              password: 'newpass'
            }
          }
        end

        before do
          # Mock server configuration update to prevent actual file changes
          allow_any_instance_of(Server).to receive(:update_configuration)
        end

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['reservation']['password']).to eq('newpass')
        end
      end


      response '401', 'Unauthorized' do
        let(:api_key) { 'invalid' }
        let(:id) { 1 }
        let(:reservation) { { reservation: { password: 'test' } } }

        run_test!
      end

      response '404', 'Reservation not found' do
        let(:api_key) { user.api_key }
        let(:id) { -1 }
        let(:reservation) { { reservation: { password: 'test' } } }

        run_test!
      end
    end

    put 'Update reservation (Step 4 - PUT method)' do
      tags 'Reservations'
      parameter name: :id, in: :path, type: :integer, description: 'Reservation ID'
      parameter name: :api_key, in: :query, type: :string, required: false, description: 'API key for authentication'
      security [ { api_key: [] }, { token_auth: [] }, { bearer_token: [] } ]

      consumes 'application/json'
      produces 'application/json'

      parameter name: :reservation, in: :body, schema: {
        type: :object,
        properties: {
          reservation: {
            type: :object,
            properties: {
              ends_at: { type: :string, format: 'date-time' },
              password: { type: :string },
              rcon: { type: :string },
              tv_password: { type: :string },
              tv_relaypassword: { type: :string },
              first_map: { type: :string },
              server_config_id: { type: :integer },
              whitelist_id: { type: :integer },
              custom_whitelist_id: { type: :integer }
            }
          }
        }
      }

      response '200', 'Reservation updated successfully' do
        let(:api_key) { user.api_key }
        let(:reservation_record) { create(:reservation, user: user, ends_at: 1.hour.from_now) }
        let(:id) { reservation_record.id }
        let(:new_ends_at) { 90.minutes.from_now.change(usec: 0) }
        let(:reservation) do
          {
            reservation: {
              ends_at: new_ends_at.iso8601,
              password: 'newpass'
            }
          }
        end

        before do
          # Mock server configuration update to prevent actual file changes
          allow_any_instance_of(Server).to receive(:update_configuration)
        end

        run_test!
      end

      response '401', 'Unauthorized' do
        let(:api_key) { 'invalid' }
        let(:id) { 1 }
        let(:reservation) { { reservation: { password: 'test' } } }

        run_test!
      end

      response '404', 'Reservation not found' do
        let(:api_key) { user.api_key }
        let(:id) { -1 }
        let(:reservation) { { reservation: { password: 'test' } } }

        run_test!
      end
    end

    delete 'Cancel/end reservation (Step 5)' do
      tags 'Reservations'
      parameter name: :id, in: :path, type: :integer, description: 'Reservation ID'
      parameter name: :api_key, in: :query, type: :string, required: false, description: 'API key for authentication'
      security [ { api_key: [] }, { token_auth: [] }, { bearer_token: [] } ]

      response '204', 'Future reservation cancelled' do
        let(:api_key) { user.api_key }
        let(:reservation_record) { create(:reservation, user: user, starts_at: 1.hour.from_now) }
        let(:id) { reservation_record.id }

        run_test!
      end

      response '200', 'Current reservation ended' do
        schema type: :object,
               properties: {
                 reservation: {
                   type: :object,
                   properties: {
                     id: { type: :integer },
                     server_id: { type: :integer },
                     starts_at: { type: :string, format: 'date-time' },
                     ends_at: { type: :string, format: 'date-time' },
                     password: { type: :string },
                     rcon: { type: :string },
                     tv_password: { type: :string },
                     tv_relaypassword: { type: :string },
                     status: { type: :string },
                     first_map: { type: :string, nullable: true },
                     tv_port: { type: :integer },
                     server_config_id: { type: :integer, nullable: true },
                     whitelist_id: { type: :integer, nullable: true },
                     custom_whitelist_id: { type: :integer, nullable: true },
                     auto_end: { type: :boolean },
                     enable_plugins: { type: :boolean },
                     enable_demos_tf: { type: :boolean },
                     sdr_ip: { type: :string, nullable: true },
                     sdr_port: { type: :integer, nullable: true },
                     sdr_tv_port: { type: :integer, nullable: true },
                     sdr_final: { type: :boolean },
                     disable_democheck: { type: :boolean },
                     last_number_of_players: { type: :integer },
                     inactive_minute_counter: { type: :integer },
                     logsecret: { type: :string },
                     start_instantly: { type: :boolean },
                     end_instantly: { type: :boolean },
                     provisioned: { type: :boolean },
                     ended: { type: :boolean },
                     steam_uid: { type: :string },
                     server: {
                       type: :object,
                       properties: {
                         id: { type: :integer },
                         name: { type: :string },
                         flag: { type: :string },
                         ip: { type: :string },
                         port: { type: :string },
                         ip_and_port: { type: :string },
                         sdr: { type: :boolean },
                         latitude: { type: :number },
                         longitude: { type: :number }
                       }
                     }
                   }
                 },
                 actions: {
                   type: :object,
                   properties: {
                     patch: { type: :string },
                     delete: { type: :string }
                   }
                 }
               }

        let(:api_key) { user.api_key }
        let(:reservation_record) { create(:reservation, user: user, provisioned: true) }
        let(:id) { reservation_record.id }

        before do
          # Mock the ReservationWorker to prevent actual server cleanup
          allow(ReservationWorker).to receive(:perform_async)
        end

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['reservation']['end_instantly']).to be_truthy
        end
      end

      response '401', 'Unauthorized' do
        let(:api_key) { 'invalid' }
        let(:id) { 1 }

        run_test!
      end

      response '404', 'Reservation not found' do
        let(:api_key) { user.api_key }
        let(:id) { -1 }

        run_test!
      end
    end
  end


  path '/api/reservations/{id}/extend' do
    post 'Extend reservation duration' do
      tags 'Reservations'
      parameter name: :id, in: :path, type: :integer, description: 'Reservation ID'
      parameter name: :api_key, in: :query, type: :string, required: false, description: 'API key for authentication'
      security [ { api_key: [] }, { token_auth: [] }, { bearer_token: [] } ]

      response '200', 'Reservation extended successfully' do
        let(:api_key) { user.api_key }
        let(:reservation_record) { create(:reservation, user: user, starts_at: Time.current, ends_at: 50.minutes.from_now, provisioned: true) }
        let(:id) { reservation_record.id }

        run_test!
      end

      response '400', 'Cannot extend reservation' do
        let(:api_key) { user.api_key }
        let(:reservation_record) { create(:reservation, user: user, starts_at: Time.current, ends_at: 50.minutes.from_now, provisioned: true) }
        let(:conflicting_reservation) { create(:reservation, server_id: reservation_record.server_id, starts_at: 1.hour.from_now, ends_at: 2.hours.from_now) }
        let(:id) { reservation_record.id }

        before do
          # Create conflicting reservation to prevent extension
          conflicting_reservation
        end

        run_test!
      end

      response '401', 'Unauthorized' do
        let(:api_key) { 'invalid' }
        let(:id) { 1 }

        run_test!
      end

      response '404', 'Reservation not found' do
        let(:api_key) { user.api_key }
        let(:id) { -1 }

        run_test!
      end
    end
  end

  # Donators API (Admin only)
  path '/api/donators/new' do
    get 'Get new donator form template' do
      tags 'Donators'
      parameter name: :api_key, in: :query, type: :string, required: false, description: 'API key for authentication'
      security [ { api_key: [] }, { token_auth: [] }, { bearer_token: [] } ]

      produces 'application/json'

      response '200', 'New donator template' do
        schema type: :object

        let(:api_key) { admin_api_key }

        run_test!
      end

      response '401', 'Unauthorized' do
        let(:api_key) { 'invalid' }

        run_test!
      end

      response '403', 'Admin access required' do
        let(:api_key) { user.api_key }

        run_test!
      end
    end
  end

  path '/api/donators/{id}' do
    get 'Get donator details' do
      tags 'Donators'
      parameter name: :id, in: :path, type: :string, description: 'Steam UID of the user'
      parameter name: :api_key, in: :query, type: :string, required: false, description: 'API key for authentication'
      security [ { api_key: [] }, { token_auth: [] }, { bearer_token: [] } ]

      produces 'application/json'

      response '401', 'Unauthorized' do
        let(:id) { user.uid }
        let(:api_key) { 'invalid' }

        run_test!
      end

      response '403', 'Admin access required' do
        let(:id) { user.uid }
        let(:api_key) { user.api_key }

        run_test!
      end

      response '404', 'Donator not found' do
        let(:id) { '999999' }
        let(:api_key) { admin_api_key }

        run_test!
      end
    end

    delete 'Remove donator status' do
      tags 'Donators'
      parameter name: :id, in: :path, type: :string, description: 'Steam UID of the user'
      parameter name: :api_key, in: :query, type: :string, required: false, description: 'API key for authentication'
      security [ { api_key: [] }, { token_auth: [] }, { bearer_token: [] } ]

      response '401', 'Unauthorized' do
        let(:id) { user.uid }
        let(:api_key) { 'invalid' }

        run_test!
      end

      response '403', 'Admin access required' do
        let(:id) { user.uid }
        let(:api_key) { user.api_key }

        run_test!
      end

      response '404', 'Donator not found' do
        let(:id) { '999999' }
        let(:api_key) { admin_api_key }

        run_test!
      end
    end
  end

  path '/api/donators' do
    post 'Create or update donator status' do
      tags 'Donators'
      parameter name: :api_key, in: :query, type: :string, required: false, description: 'API key for authentication'
      security [ { api_key: [] }, { token_auth: [] }, { bearer_token: [] } ]

      consumes 'application/json'
      produces 'application/json'

      parameter name: :donator, in: :body, schema: {
        type: :object,
        properties: {
          donator: {
            type: :object,
            properties: {
              steam_uid: { type: :string, description: 'Steam UID of the user' },
              expires_at: { type: :string, format: 'date-time', description: 'When donator status expires' }
            },
            required: [ 'steam_uid', 'expires_at' ]
          }
        }
      }

      response '401', 'Unauthorized' do
        let(:api_key) { 'invalid' }
        let(:donator) do
          {
            donator: {
              steam_uid: user.uid,
              expires_at: (Time.current + 1.month).iso8601
            }
          }
        end

        run_test!
      end

      response '403', 'Admin access required' do
        let(:api_key) { user.api_key }
        let(:donator) do
          {
            donator: {
              steam_uid: user.uid,
              expires_at: (Time.current + 1.month).iso8601
            }
          }
        end

        run_test!
      end

      response '404', 'User not found' do
        let(:api_key) { admin_api_key }
        let(:donator) do
          {
            donator: {
              steam_uid: '999999',
              expires_at: (Time.current + 1.month).iso8601
            }
          }
        end

        run_test!
      end
    end
  end

  # League Requests API (Admin/League Admin only)
  path '/api/league_requests' do
    get 'Search league requests' do
      tags 'League Requests'
      parameter name: :api_key, in: :query, type: :string, required: false, description: 'API key for authentication'
      parameter name: 'league_request[ip]', in: :query, type: :string, required: false, description: 'IP address to search for'
      parameter name: 'league_request[steam_uid]', in: :query, type: :string, required: false, description: 'Steam UID to search for'
      parameter name: 'league_request[reservation_ids]', in: :query, type: :string, required: false, description: 'Reservation IDs to search for'
      parameter name: 'league_request[cross_reference]', in: :query, type: :boolean, required: false, description: 'Enable cross-referencing in search'
      security [ { api_key: [] }, { token_auth: [] }, { bearer_token: [] } ]

      produces 'application/json'

      response '401', 'Unauthorized' do
        let(:api_key) { 'invalid' }

        run_test!
      end

      response '403', 'Admin or league admin access required' do
        let(:api_key) { user.api_key }

        run_test!
      end
    end
  end
end
