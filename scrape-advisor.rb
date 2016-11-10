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
      csv << ['name', 'city', 'address', 'extended_address', 'postcode', 'country', 'lat', 'lng', 'bubble_rating', 'star_rating', 'review_count']
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
      details   = (@mechanize.get("#{@base_url}#{hotel.at('.property_title').attr('href')}") rescue '')
      name      = (hotel.at('a').text.strip rescue '')
      address   = (details.at('span.street-address').text.strip.gsub('"', '') rescue '')
      city      = (details.at('//span[@property="addressLocality"]').text.strip.gsub('"', '') rescue '')
      postcode  = (details.at('//span[@property="postalCode"]').text.strip.gsub('"', '') rescue '')
      extended  = (details.at('span.extended-address').text.strip.gsub('"', '') rescue '')
      country   = (details.at('span.country-name').text.strip.gsub('"', '') rescue '')
      rating    = (details.at('span.ui_bubble_rating').attr('content') rescue '')
      stars     = (details.at('div.ui_star_rating').attr('class') rescue '')
      reviews   = (details.at('//a[@property="reviewCount"]').attr('content') rescue '')
      latitude  = (details.at('div.mapContainer').attr('data-lat') rescue '')
      longitude = (details.at('div.mapContainer').attr('data-lng') rescue '')

      puts "[HOTEL] #{name}".green

      # Add the data we can find to the listings array
      @listings << {
        name:     name,
        city:     city,
        address:  address,
        extended: extended,
        postcode: postcode,
        coutry:   country,
        lat:      latitude,
        lng:      longitude,
        rating:   rating,
        stars:    (stars.split(' ').last.split('_').last / 10 rescue nil),
        reviews:  reviews
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
          listing[:extended],
          listing[:postcode],
          listing[:country],
          listing[:latitude],
          listing[:longitude],
          listing[:rating],
          listing[:stars],
          listing[:reviews]
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
