require 'csv'
require 'colorize'
require 'mechanize'

class ScrapeAdvisor

  def initialize(page)
    @mechanize = Mechanize.new
    @base_url  = 'https://www.tripadvisor.com'
    @city_page = page

    CSV.open("tripadvisor_data.csv", "w") do |csv|
      # Puts some headers on top of the columns
      csv << ['name', 'city', 'address', 'postcode']
    end

    puts '[SCRAPER] start'.green
  end

  def run(url=nil)
    # Use mechanize to get and parse the URL
    if url
      puts "[SCRAPE] #{@base_url}#{url}".green
      rawpage = @mechanize.get("#{@base_url}#{url}")
    else
      puts "[SCRAPE] #{@base_url}/Hotels-g187070-oa20-France-Hotels.html#LEAF_GEO_LIST".green
      rawpage = @mechanize.get("#{@base_url}/Hotels-g187070-oa20-France-Hotels.html#LEAF_GEO_LIST")
    end

    get_city_listings(rawpage)

    @city_page += 1

    rawpage.search('a.pageNum').each do |paginate|
      if paginate.text.strip.to_i == @city_page
        puts "[CITY PAGE] #{@city_page}".green
        # Just call yourself again, but move to next page
        run(paginate.attr('href'))
      end
    end
  end

  def get_city_listings(rawpage)
    rawpage.search('div.geo_name').each do |city|
      pages = 0

      puts "[CITY] #{city.at('a').text.strip}"
      get_hotels_per_city(city.at('a').attr('href'), pages)
    end
  end

  def get_hotels_per_city(url, pages)
    @listings = []
    citylist  = @mechanize.get("#{@base_url}#{url}")

    citylist.search('div.listing').each do |hotel|
      details  = @mechanize.get("#{@base_url}#{hotel.at('.property_title').attr('href')}")
      name     = hotel.at('a').text.strip
      address  = details.at('span.street-address').text.strip.gsub('"', '')
      city     = details.at('span.addressLocality').text.strip.gsub('"', '')
      postcode = details.at('span.postalCode').text.strip.gsub('"', '')

      puts "[HOTEL] #{name}"

      # Add the data we can find to the listings array
      @listings << {
        name:     name,
        city:     city,
        address:  address,
        postcode: postcode
      }
    end

    # Let's output to a CSV file
    CSV.open("tripadvisor_data.csv", "a") do |csv|
      # Add all the listings we have collected to the CSV file
      @listings.each do |listing|
        csv << [
          listing[:name],
          listing[:city],
          listing[:address],
          listing[:postcode]
        ]
      end
    end

    pages += 1

    citylist.search('a.pageNum').each do |paginate|
      if paginate.text.strip.to_i == @page
        puts "[PAGE] #{@page}".green
        # Just call yourself again, but move to next page
        get_hotels_per_city(paginate.attr('href'), pages)
      end
    end
  end

end

scrape_advisor = ScrapeAdvisor.new(2)
scrape_advisor.run
