#!/usr/bin/env ruby
# frozen_string_literal: true

require 'minitest/autorun'

# Load only the testable classes (no inotify dependency)
require_relative 'lib/domain_filter'
require_relative 'lib/hosts_generator'

class DomainFilterTest < Minitest::Test
  def setup
    @filter = DomainFilter.new('example.org')
  end

  # Test filtering logic

  def test_filter_simple_hostnames
    domains = %w[wiki gitlab nextcloud]
    result = @filter.filter(domains)

    assert_equal %w[gitlab nextcloud wiki], result
  end

  def test_filter_external_domain_hostnames
    domains = %w[wiki.example.org gitlab.example.org]
    result = @filter.filter(domains)

    assert_equal %w[gitlab.example.org wiki.example.org], result
  end

  def test_filter_mixed_hostnames
    domains = %w[wiki gitlab.example.org nextcloud mail.example.org]
    result = @filter.filter(domains)

    assert_equal %w[gitlab.example.org mail.example.org nextcloud wiki], result
  end

  def test_filter_excludes_non_matching_fqdn
    # Domains that have dots but don't end with the external domain should be excluded
    domains = %w[wiki gitlab.other.com mail.example.org test.different.net]
    result = @filter.filter(domains)

    assert_equal %w[mail.example.org wiki], result
  end

  def test_filter_removes_duplicates
    domains = %w[wiki wiki gitlab gitlab]
    result = @filter.filter(domains)

    assert_equal %w[gitlab wiki], result
  end

  def test_filter_sorts_results
    domains = %w[zebra alpha middle]
    result = @filter.filter(domains)

    assert_equal %w[alpha middle zebra], result
  end

  def test_filter_empty_list
    result = @filter.filter([])

    assert_equal [], result
  end

  def test_filter_only_excluded_domains
    # All domains have dots but don't match external domain
    domains = %w[test.other.com mail.different.org]
    result = @filter.filter(domains)

    assert_equal [], result
  end

  # Test JSON parsing from rows

  def test_parse_from_rows_single_domain
    rows = [['["wiki"]']]
    result = @filter.parse_from_rows(rows)

    assert_equal ['wiki'], result
  end

  def test_parse_from_rows_multiple_domains
    rows = [['["wiki", "gitlab"]']]
    result = @filter.parse_from_rows(rows)

    assert_equal %w[wiki gitlab], result
  end

  def test_parse_from_rows_multiple_rows
    rows = [['["wiki"]'], ['["gitlab"]'], ['["nextcloud"]']]
    result = @filter.parse_from_rows(rows)

    assert_includes result, 'wiki'
    assert_includes result, 'gitlab'
    assert_includes result, 'nextcloud'
  end

  def test_parse_from_rows_removes_duplicates
    rows = [['["wiki", "gitlab"]'], ['["gitlab", "nextcloud"]']]
    result = @filter.parse_from_rows(rows)

    assert_equal 3, result.uniq.length
  end

  def test_parse_from_rows_empty
    result = @filter.parse_from_rows([])

    assert_equal [], result
  end

  # Edge cases

  def test_filter_with_subdomain_of_external_domain
    domains = %w[deep.sub.example.org wiki.example.org]
    result = @filter.filter(domains)

    # Both should be included as they end with .example.org
    assert_equal %w[deep.sub.example.org wiki.example.org], result
  end

  def test_filter_external_domain_without_subdomain
    # The external domain itself shouldn't match (it's ".example.org" not "example.org")
    filter = DomainFilter.new('example.org')
    domains = %w[example.org wiki.example.org]
    result = filter.filter(domains)

    # example.org has a dot but doesn't end with ".example.org"
    assert_equal ['wiki.example.org'], result
  end

  def test_filter_case_sensitivity
    # Domains are case-sensitive (DNS should handle case-insensitivity)
    domains = %w[Wiki wiki WIKI]
    result = @filter.filter(domains)

    assert_equal %w[WIKI Wiki wiki], result
  end
end

class HostsGeneratorContentTest < Minitest::Test
  # Test the host line building logic
  # We can't easily test the full generator without mocking the database,
  # but we can test the content building with a mock config

  class MockConfig
    attr_accessor :ip_address, :domain_name, :external_domain, :local_suffix, :dnsmasq_path, :db_path

    def initialize
      @ip_address = '192.168.1.100'
      @domain_name = 'hackerspace.lan'
      @external_domain = 'example.org'
      @local_suffix = '.local'
      @dnsmasq_path = '/tmp/hosts'
      @db_path = '/tmp/db.sqlite'
    end
  end

  class MockLogger
    def info(_msg); end

    def debug(_msg); end

    def error(_msg); end

    def warn(_msg); end
  end

  def setup
    @config = MockConfig.new
    @logger = MockLogger.new
  end

  def test_build_host_line_simple_hostname
    generator = HostsGenerator.new(@config, @logger)
    line = generator.build_host_line('wiki')

    assert_equal "192.168.1.100 wiki wiki.hackerspace.lan wiki.local\n", line
  end

  def test_build_host_line_external_domain
    generator = HostsGenerator.new(@config, @logger)
    line = generator.build_host_line('wiki.example.org')

    assert_equal "192.168.1.100 wiki.example.org\n", line
  end

  def test_build_host_line_without_local_suffix
    @config.local_suffix = ''
    generator = HostsGenerator.new(@config, @logger)
    line = generator.build_host_line('wiki')

    assert_equal "192.168.1.100 wiki wiki.hackerspace.lan\n", line
  end

  def test_build_host_line_custom_local_suffix
    @config.local_suffix = '.home'
    generator = HostsGenerator.new(@config, @logger)
    line = generator.build_host_line('wiki')

    assert_equal "192.168.1.100 wiki wiki.hackerspace.lan wiki.home\n", line
  end
end
