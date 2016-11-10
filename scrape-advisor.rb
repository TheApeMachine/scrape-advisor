require 'csv'
require 'colorize'
require 'mechanize'

class ScrapeAdvisor

  def initialize(page)
    @mechanize = Mechanize.new
    @base_url  = 'https://www.tripadvisor.com'
    @listings  = []
    @page      = page

    CSV.open("tripadvisor_data.csv", "w") do |csv|
      # Puts some headers on top of the columns
      csv << ['name', 'address']
    end
  end

  def run(url=nil)
    puts '[SCRAPE] start'.green

    # Use mechanize to get and parse the URL
    if url
      puts "[SCRAPE] #{@base_url}#{url}".green
      rawpage = @mechanize.get("#{@base_url}#{url}")
    else
      puts "[SCRAPE] #{@base_url}/Hotels-g187144-Ile_de_France-Hotels.html".green
      rawpage = @mechanize.get("#{@base_url}/Hotels-g187144-Ile_de_France-Hotels.html")
    end

    # Search for the items with a class of listing and loop over them
    rawpage.search('div.listing').each do |listing|
      puts "[DETAIL] #{@base_url}#{listing.at('.property_title').attr('href')}".green

      details = @mechanize.get("#{@base_url}#{listing.at('.property_title').attr('href')}")
      name    = listing.at('a').text.strip
      address = details.at('span.street-address').text.strip.gsub('"', '')

      # Add the data we can find to the listings array
      @listings << {
        name: name,
        address: address
      }
    end

    # Let's output to a CSV file
    CSV.open("tripadvisor_data.csv", "a") do |csv|
      # Add all the listings we have collected to the CSV file
      @listings.each do |listing|
        csv << [
          listing[:name],
          listing[:address]
        ]
      end
    end

    @page += 1

    rawpage.search('a.pageNum').each do |paginate|
      if paginate.text.strip.to_i == @page
        puts "[PAGE] #{@page}".green
        # Just call yourself again, but move to next page
        run(paginate.attr('href'))
      end
    end
  end

end

scrape_advisor = ScrapeAdvisor.new(1)
scrape_advisor.run
