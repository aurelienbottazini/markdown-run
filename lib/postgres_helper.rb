require_relative "test_silencer"

module PostgresHelper
  class << self
    def psql_command
      @psql_command ||= detect_psql_command
    end

    def available?
      return false if psql_command.nil?

      # If using Docker, check required env vars are present
      if using_docker?
        has_required_env_vars?
      else
        true
      end
    end

    def using_docker?
      cmd = psql_command
      cmd && cmd.start_with?("docker exec")
    end

    # Reset cached command detection (for tests)
    def reset_cache!
      @psql_command = nil
    end

    def validate_env_vars!
      return unless using_docker?

      required_vars = ["PGUSER", "PGDATABASE"]
      missing_vars = required_vars.reject { |var| ENV[var] }

      if missing_vars.any?
        TestSilencer.abort_unless_testing "Error: PostgreSQL is running in Docker but required environment variables are missing: #{missing_vars.join(", ")}. Please set these variables before running psql commands."
      end
    end

    private

    def has_required_env_vars?
      required_vars = ["PGUSER", "PGDATABASE"]
      required_vars.all? { |var| ENV[var] }
    end

    def detect_psql_command
      # Check if psql is available locally
      return "psql" if system("command -v psql > /dev/null 2>&1")

      # Check if docker is available
      return nil unless system("command -v docker > /dev/null 2>&1")

      # Find running postgres container
      container_id = find_postgres_container
      return nil if container_id.nil? || container_id.empty?

      # Build docker exec command with environment variables passed through
      env_vars = build_env_vars
      "docker exec -i -u postgres #{env_vars}#{container_id} psql"
    end

    def build_env_vars
      # Pass through PostgreSQL environment variables if they exist
      pg_env_vars = [ "PGUSER", "PGPASSWORD", "PGDATABASE", "PGHOST", "PGPORT" ]
      env_flags = pg_env_vars.map do |var|
        value = ENV[var]
        "-e #{var}=\"#{value}\" " if value
      end.compact.join
      env_flags.empty? ? "" : "#{env_flags} "
    end

    def find_postgres_container
      # Try to find a running postgres container
      # First, check for container with postgres in the name
      output = `docker ps --filter "ancestor=postgres" --format "{{.ID}}" 2>/dev/null`.strip
      return output.split("\n").first unless output.empty?

      # Alternative: check for containers with "postgres" in name
      output = `docker ps --filter "name=postgres" --format "{{.ID}}" 2>/dev/null`.strip
      return output.split("\n").first unless output.empty?

      # Last resort: check if any running container has psql command
      containers = `docker ps --format "{{.ID}}" 2>/dev/null`.strip.split("\n")
      containers.each do |container_id|
        has_psql = system("docker exec #{container_id} which psql > /dev/null 2>&1")
        return container_id if has_psql
      end

      nil
    end
  end
end
