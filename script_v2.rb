# app/lib/domain_finder.rb
require 'net/http'
require 'uri'
require 'nokogiri'

class DomainFinder
  BLACKLISTED_DOMAINS = %w[
    wikipedia.org linkedin.com facebook.com twitter.com
    instagram.com youtube.com crunchbase.com bloomberg.com
  ].freeze

  class << self
    def find(company_name)
      return if company_name.blank?

      html_content = search_duckduckgo(company_name)
      return unless html_content

      extract_primary_domain(html_content, company_name)
    end

    private

    def search_duckduckgo(company_name)
      url = URI("https://html.duckduckgo.com/html/?q=#{CGI.escape(company_name + ' official website')}")
      
      http = Net::HTTP.new(url.host, url.port)
      http.use_ssl = true
      http.read_timeout = 10
      
      request = Net::HTTP::Get.new(url)
      request['User-Agent'] = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
      
      response = http.request(request)
      response.is_a?(Net::HTTPSuccess) ? response.body : nil
    rescue StandardError => e
      Rails.logger.error("DomainFinder search error: #{e.message}")
      nil
    end

    def extract_primary_domain(html_content, company_name)
      doc = Nokogiri::HTML(html_content)
      results = doc.css('a.result__url')
      
      results.each do |result|
        domain = clean_domain(result.text.strip)
        next unless valid_domain?(domain)
        
        return domain if domain_matches_company?(domain, company_name)
      end

      # If no matching domain found, return the first valid one
      results.each do |result|
        domain = clean_domain(result.text.strip)
        return domain if valid_domain?(domain)
      end
      
      nil
    end

    def clean_domain(url)
      url = "http://#{url}" unless url.start_with?('http://', 'https://')
      uri = URI.parse(url)
      uri.host.to_s.downcase.sub(/^www\./, '')
    rescue StandardError
      nil
    end

    def valid_domain?(domain)
      domain.present? &&
        domain.include?('.') &&
        !domain.split('.').first.empty? &&
        !BLACKLISTED_DOMAINS.include?(domain)
    end

    def domain_matches_company?(domain, company_name)
      company_words = company_name.downcase.split
      domain_words = domain.split('.').first.split('-')
      (company_words & domain_words).any?
    end
  end
end
