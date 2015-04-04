require 'date'
require 'open-uri'
require 'nokogiri'
require 'capybara'

CAMPSITE_URLS = {
  samuel_p_taylor: ->(date) { "http://www.reserveamerica.com/camping/Samuel_P_Taylor_Sp/r/campsiteDetails.do?arvdate=#{date.strftime('%m/%d/%Y')}&contractCode=CA&parkId=120081&siteId=3053" }
}

def find_available_weekends(campsite_url, preferred_day: :friday, length_of_stay_in_nights: 2)
  today = Date.today
  weekends = get_weekends(today, preferred_day)
  available_weekends = []

  weekends.each do |day|
  # day = weekends.first
    url = CAMPSITE_URLS[:samuel_p_taylor].(day)
    page = Capybara::Node::Simple.new(Nokogiri::HTML(open(url)))
    availability = []
    availability << page.find('#avail1')[:title]

    length_of_stay_in_nights.times do |i|
      availability << page.find("#avail#{i + 2}")[:title]
    end

    available_weekends << day if availability.all? { |status| p 'the status!', status; status == 'Available' }
  end

  available_weekends
end

def get_weekends(today, preferred_day)
  weekends = []

  today.upto(today + 365).each do |day|
    weekends << day if day.send("#{preferred_day}?")

    break if weekends.length >= 40
  end

  weekends
end

p find_available_weekends(nil)
