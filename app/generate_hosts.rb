#!/usr/bin/env ruby
# frozen_string_literal: true

require 'logger'
require 'rb-inotify'
require_relative 'lib/config'
require_relative 'lib/domain_filter'
require_relative 'lib/hosts_generator'

# File watcher with debouncing
class DatabaseWatcher
  def initialize(config, generator, logger)
    @config = config
    @generator = generator
    @logger = logger
    @last_event_time = nil
    @pending_regeneration = false
    @mutex = Mutex.new
    @running = true
  end

  def start
    @logger.info("Starting continuous monitoring of database file: #{@config.db_path}")
    setup_signal_handlers

    notifier = INotify::Notifier.new

    # Only watch close_write to avoid race conditions with partial writes
    notifier.watch(@config.db_path, :close_write) do |_event|
      handle_change
    end

    @logger.info("Watching for changes. Send SIGTERM or SIGINT to stop.")

    # Main loop with graceful shutdown support
    while @running
      notifier.process if notifier.readable?(1)
      process_pending_regeneration
    end

    notifier.close
    @logger.info("Monitoring stopped")
  end

  private

  def setup_signal_handlers
    %w[INT TERM].each do |signal|
      Signal.trap(signal) do
        @logger.info("Received #{signal}, shutting down gracefully...")
        @running = false
      end
    end
  end

  def handle_change
    @mutex.synchronize do
      @last_event_time = Time.now
      @pending_regeneration = true
      @logger.debug("Database change detected, debouncing...")
    end
  end

  def process_pending_regeneration
    should_regenerate = false

    @mutex.synchronize do
      if @pending_regeneration && @last_event_time
        elapsed = Time.now - @last_event_time
        if elapsed >= @config.debounce_seconds
          should_regenerate = true
          @pending_regeneration = false
        end
      end
    end

    if should_regenerate
      @logger.info("Debounce period elapsed, regenerating hosts file...")
      @generator.generate
    end
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
