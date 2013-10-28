module ActiveRecord

  class Migrator
    private
    def initialize(direction, migrations, target_version = nil)
      raise StandardError.new("This database does not yet support migrations") unless Base.connection.supports_migrations?

      @direction         = direction
      @target_version    = target_version
      @migrated_versions = nil
      @migrations        = migrations

      validate(@migrations)

      ActiveRecord::Schema.suppress_messages{ ActiveRecord::Schema.initialize_schema_migrations_table }
    end
  end

end
