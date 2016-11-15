require 'csv'
require 'colorize'
require 'mechanize'

class ScrapeAdvisor

  def initialize(page)
    @mechanize = Mechanize.new
    @base_url  = 'https://www.tripadvisor.com'
    @city_page = page
    @services  = []

    CSV.open("tripadvisor_data.csv", "w") do |csv|
      # Puts some headers on top of the columns
      csv << ['id', 'name', 'city', 'address', 'extended_address', 'postcode', 'country', 'lat', 'lng', 'bubble_rating', 'star_rating', 'review_count']
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
        puts "[CITY PAGE] #{@city_page}".yellow
        # Just call yourself again, but move to next page
        run(paginate.attr('href'))
      end
    end

    add_services
  end

  def get_city_listings(rawpage)
    rawpage.search('div.geo_name').each do |city|
      pages = 1

      puts "[CITY] #{city.at('a').text.strip}"
      get_hotels_per_city(city.at('a').attr('href'), pages)
    end
  end

  def get_hotels_per_city(url, pages)
    @listings = []
    citylist  = @mechanize.get("#{@base_url}#{url}")

    citylist.search('div.listing').each do |hotel|
      id        = SecureRandom.hex
      details   = (@mechanize.get("#{@base_url}#{hotel.at('.property_title').attr('href')}") rescue '')
      name      = (hotel.at('a').text.strip rescue '')
      address   = (details.at('span.street-address').text.strip.gsub('"', '') rescue '')
      city      = (details.at('//span[@property="addressLocality"]').text.strip.gsub('"', '') rescue '')
      postcode  = (details.at('//span[@property="postalCode"]').text.strip.gsub('"', '') rescue '')
      extended  = (details.at('span.extended-address').text.strip.gsub('"', '') rescue '')
      country   = details.at('span.country-name').text.strip.gsub('"', '')
      rating    = (details.at('span.ui_bubble_rating').attr('content') rescue '')
      stars     = (details.at('div.ui_star_rating').attr('class') rescue '')
      reviews   = (details.at('//a[@property="reviewCount"]').attr('content') rescue '')
      latitude  = (details.at('div.mapContainer').attr('data-lat') rescue '')
      longitude = (details.at('div.mapContainer').attr('data-lng') rescue '')

      puts "[HOTEL] #{name}".green

      hotelservices = []

      # Find all the services this hotel has to offer
      details.search('//div[@class="amenity_row"]//div[@class="amenity_lst"]//li').children.each do |amenity|
        symbol = amenity.text.strip.downcase.gsub(' ', '_')

        if !symbol.empty?
          hotelservices << {
            symbol => true
          }
        end
      end

      # Store the services so we can add them to the hotel list later
      @services << {
        id:       id,
        services: hotelservices
      }

      # Add the data we can find to the listings array
      @listings << {
        id:       id,
        name:     name,
        city:     city,
        address:  address,
        extended: extended,
        postcode: postcode,
        country:  country,
        lat:      latitude,
        lng:      longitude,
        rating:   rating,
        stars:    (stars.split(' ').last.split('_').last.to_i / 10 rescue nil),
        reviews:  reviews
      }
    end

    # Let's output to a CSV file
    CSV.open("tripadvisor_data.csv", "a") do |csv|
      # Add all the listings we have collected to the CSV file
      @listings.each do |listing|
        csv << [
          listing[:id],
          listing[:name],
          listing[:city],
          listing[:address],
          listing[:extended],
          listing[:postcode],
          listing[:country],
          listing[:lat],
          listing[:lng],
          listing[:rating],
          listing[:stars],
          listing[:reviews]
        ]
      end
    end

    pages += 1

    citylist.search('a.pageNum').each do |paginate|
      if paginate.text.strip.to_i == pages
        puts "[HOTEL PAGE] #{pages}".yellow
        # Just call yourself again, but move to next page
        get_hotels_per_city(paginate.attr('href'), pages)
      end
    end
  end

  def add_services
    # Let's get all the unique service names
    columns = @services.map{
      |hotel| hotel[:services].map{
        |service| service.map{
          |key, value| key
        }
      }
    }.flatten.uniq

    # Add the columns to the CSV file
    CSV.open("tripadvisor_data_with_services.csv", "w") do |csv|
      csv << ['id', 'name', 'city', 'address', 'extended_address', 'postcode', 'country', 'lat', 'lng', 'bubble_rating', 'star_rating', 'review_count'] + columns

      CSV.foreach('tripadvisor_data.csv', headers: true) do |row|
        new_data = [
          row['id'],
          row['name'],
          row['city'],
          row['address'],
          row['extended_address'],
          row['postcode'],
          row['country'],
          row['lat'],
          row['lng'],
          row['bubble_rating'],
          row['star_rating'],
          row['review_count']
        ]

        add_data = []

        columns.each do |column|
          @services.select{|hotel| hotel[:id] == row['id']}.each do |service|
            if !service[:services].select{|s| s[column]}.empty?
              add_data << 1
            else
              add_data << 0
            end
          end
        end

        csv << new_data + add_data
      end
    end
  end

end

scrape_advisor = ScrapeAdvisor.new(2)
scrape_advisor.run
