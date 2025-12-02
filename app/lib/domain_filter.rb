# frozen_string_literal: true

require 'json'

# Domain filtering logic - separated for testability
class DomainFilter
  def initialize(external_domain)
    @external_domain = external_domain
  end

  # Filter domains to only include simple hostnames and those ending with external domain
  def filter(domains)
    simple_hostnames = domains.reject { |hostname| hostname.include?('.') }
    external_hostnames = domains.select { |hostname| hostname.end_with?(".#{@external_domain}") }
    (simple_hostnames + external_hostnames).uniq.sort
  end

  # Parse domain names from database rows
  def parse_from_rows(rows)
    rows.flatten.map { |domains| JSON.parse(domains) }.flatten.uniq
  end
end

