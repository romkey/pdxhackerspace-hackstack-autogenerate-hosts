#!/usr/bin/env ruby
# frozen_string_literal: true

require 'logger'
require_relative 'lib/config'
require_relative 'lib/domain_filter'
require_relative 'lib/hosts_generator'

# File watcher using polling (works across Docker container boundaries)
class DatabaseWatcher
  def initialize(config, generator, logger)
    @config = config
    @generator = generator
    @logger = logger
    @running = true
    @last_mtime = nil
  end

  def start
    @logger.info("Starting continuous monitoring of database file: #{@config.db_path}")
    @logger.info("Polling interval: #{@config.poll_seconds} seconds")
    setup_signal_handlers

    # Get initial mtime
    @last_mtime = get_mtime

    @logger.info("Watching for changes. Send SIGTERM or SIGINT to stop.")

    while @running
      sleep @config.poll_seconds
      check_for_changes
    end

    @logger.info("Monitoring stopped (received shutdown signal)")
  end

  private

  def setup_signal_handlers
    %w[INT TERM].each do |signal|
      Signal.trap(signal) do
        @logger.info("Received SIG#{signal}, shutting down gracefully...")
        @running = false
      end
    end

    Signal.trap('HUP') do
      @logger.info("Received SIGHUP, forcing regeneration...")
      @generator.generate
    end
  end

  def get_mtime
    # Check mtime of main db and WAL file (SQLite WAL mode)
    files = [@config.db_path, "#{@config.db_path}-wal"]
    mtimes = files.filter_map do |f|
      File.mtime(f) if File.exist?(f)
    end
    mtimes.max
  rescue Errno::ENOENT
    nil
  end

  def check_for_changes
    current_mtime = get_mtime

    if current_mtime && current_mtime != @last_mtime
      @logger.info("Database change detected (mtime: #{current_mtime})")
      @last_mtime = current_mtime
      @generator.generate
    end
  rescue StandardError => e
    @logger.error("Error checking for changes: #{e.message}")
  end
end

# Main application
class Application
  def initialize
    @logger = setup_logger
    @config = Config.new(@logger)
    update_log_level
    @generator = HostsGenerator.new(@config, @logger)
  end

  def run
    # Generate hosts file initially
    unless @generator.generate
      @logger.error("Initial generation failed, exiting")
      exit 1
    end

    # Start watching for changes
    watcher = DatabaseWatcher.new(@config, @generator, @logger)
    watcher.start
  end

  private

  def setup_logger
    logger = Logger.new($stdout)
    logger.formatter = proc do |severity, datetime, _progname, msg|
      "[#{datetime.strftime('%Y-%m-%d %H:%M:%S')}] #{severity}: #{msg}\n"
    end
    logger.level = Logger::INFO
    logger
  end

  def update_log_level
    level = case @config.log_level
            when 'DEBUG' then Logger::DEBUG
            when 'WARN' then Logger::WARN
            when 'ERROR' then Logger::ERROR
            else Logger::INFO
            end
    @logger.level = level
  end
end

# Run the application if executed directly
Application.new.run if __FILE__ == $PROGRAM_NAME
