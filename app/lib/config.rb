# frozen_string_literal: true

# Configuration class to handle environment variables with validation and defaults
class Config
  REQUIRED_VARS = %w[TARGET_IP DOMAIN_NAME EXTERNAL_DOMAIN DNSMASQ_PATH DB_PATH].freeze
  OPTIONAL_VARS = {
    'LOCAL_SUFFIX' => '.local',           # Set to empty string to disable
    'LOG_LEVEL' => 'INFO',                 # DEBUG, INFO, WARN, ERROR
    'DEBOUNCE_SECONDS' => '1'              # Delay after file change before regenerating
  }.freeze

  attr_reader :ip_address, :domain_name, :external_domain, :dnsmasq_path, :db_path,
              :local_suffix, :log_level, :debounce_seconds

  def initialize(logger)
    @logger = logger
    validate_required_vars!
    load_config
  end

  private

  def validate_required_vars!
    missing = REQUIRED_VARS.select { |var| ENV[var].nil? || ENV[var].empty? }
    return if missing.empty?

    missing.each { |var| @logger.error("Missing required environment variable: #{var}") }
    exit 1
  end

  def load_config
    @ip_address = ENV['TARGET_IP']
    @domain_name = ENV['DOMAIN_NAME']
    @external_domain = ENV['EXTERNAL_DOMAIN']
    @dnsmasq_path = ENV['DNSMASQ_PATH']
    @db_path = ENV['DB_PATH']

    # Optional with defaults
    @local_suffix = ENV.fetch('LOCAL_SUFFIX', OPTIONAL_VARS['LOCAL_SUFFIX'])
    @log_level = ENV.fetch('LOG_LEVEL', OPTIONAL_VARS['LOG_LEVEL']).upcase
    @debounce_seconds = ENV.fetch('DEBOUNCE_SECONDS', OPTIONAL_VARS['DEBOUNCE_SECONDS']).to_f
  end
end

