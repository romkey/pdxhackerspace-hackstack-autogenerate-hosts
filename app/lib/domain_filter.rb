# frozen_string_literal: true

require 'json'

# Domain filtering logic - separated for testability
class DomainFilter
  def initialize(external_domain, internal_domain = nil)
    @external_domain = external_domain
    @internal_domain = internal_domain
  end

  # Filter domains:
  # - Keep simple hostnames (no dots): wiki, gitlab
  # - Keep hostnames ending with external domain: wiki.example.org
  # - Keep hostnames ending with internal domain: npm.staging.ctrlh
  # - Keep internal names with single dot: assets.cats, app.internal
  # - Exclude external FQDNs from other domains: wiki.other.com
  def filter(domains)
    domains.select do |hostname|
      !hostname.include?('.') ||                        # Simple hostname
        hostname.end_with?(".#{@external_domain}") ||   # Matches external domain
        (@internal_domain && hostname.end_with?(".#{@internal_domain}")) ||  # Matches internal domain
        hostname.count('.') == 1                        # Internal name with single dot
    end.uniq.sort
  end

  # Parse domain names from database rows
  def parse_from_rows(rows)
    rows.flatten.map { |domains| JSON.parse(domains) }.flatten.uniq
  end
end

