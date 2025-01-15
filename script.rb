require 'net/http'
require 'uri'
require 'nokogiri'
require 'cgi'

class DomainFinder
  def initialize
    @headers = {
      'User-Agent' => 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36'
    }
    @blacklist = Set.new([
      'wikipedia.org', 'linkedin.com', 'facebook.com', 'twitter.com',
      'instagram.com', 'youtube.com', 'crunchbase.com', 'bloomberg.com'
    ])
  end

  def get_duckduckgo_results(query)
    encoded_query = CGI.escape(query)
    url = URI("https://html.duckduckgo.com/html/?q=#{encoded_query}")
    
    begin
      http = Net::HTTP.new(url.host, url.port)
      http.use_ssl = true
      http.read_timeout = 10
      
      request = Net::HTTP::Get.new(url)
      @headers.each { |key, value| request[key] = value }
      
      response = http.request(request)
      return response.body if response.is_a?(Net::HTTPSuccess)
    rescue StandardError => e
      puts "Search error: #{e.message}"
    end
    nil
  end

  def extract_domain(url)
    begin
      # Add scheme if missing
      url = "http://#{url}" unless url.start_with?('http://', 'https://')
      
      uri = URI.parse(url)
      domain = uri.host.downcase
      
      # Remove www. and any other subdomains
      domain = domain.sub(/^www\./, '')
      
      # Basic validation
      return nil if !domain.include?('.') || domain.split('.').first.empty?
      
      domain
    rescue StandardError
      nil
    end
  end

  def find_company_domain(company_name)
    # Prepare search query
    query = "#{company_name} official website"
    
    # Get search results
    html_content = get_duckduckgo_results(query)
    return nil unless html_content
    
    # Parse results
    doc = Nokogiri::HTML(html_content)
    results = doc.css('a.result__url')
    
    domains = []
    results.each do |result|
      url_text = result.text.strip
      domain = extract_domain(url_text)
      
      next unless domain && !@blacklist.include?(domain)
      
      # Check if domain contains company name (case insensitive)
      company_words = company_name.downcase.split
      domain_words = domain.downcase.split('.').first.split('-')
      
      # If there's word overlap, prioritize this domain
      return domain if (company_words & domain_words).any?
      
      domains << domain
    end
    
    # Return first valid domain if no priority match found
    domains.first
  end
end

def main
  finder = DomainFinder.new
  
  puts "\nCompany Domain Finder"
  puts "=" * 50
  
  loop do
    print "\nEnter company name (or 'quit' to exit): "
    company_name = gets.chomp.strip
    
    next if company_name.empty?
    
    if company_name.downcase == 'quit'
      puts "\nGoodbye!"
      break
    end
    
    puts "\nSearching for #{company_name}'s domain..."
    domain = finder.find_company_domain(company_name)
    
    if domain
      puts "Found domain: #{domain}"
    else
      puts "No domain found. Please try a different company name."
    end
    
    # Small delay to prevent rate limiting
    sleep(1)
  end
end

if __FILE__ == $PROGRAM_NAME
  main
end
