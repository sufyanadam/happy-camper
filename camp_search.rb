require 'date'
require 'open-uri'
require 'capybara'

CAMPSITE_URLS = {
  samuel_p_taylor: ->(date) { "http://www.reserveamerica.com/campsiteCalendar.do?page=matrix&calarvdate=#{date.strftime('%m/%d/%Y')}&contractCode=CA&parkId=120081"
  }
}

def find_available_weekends(campsite_url, preferred_day: :friday, length_of_stay_in_nights: 2)
  today = Date.today
  weekends = get_weekends(today, preferred_day)
  available_weekends = []

  weekends.each do |day|
    url = CAMPSITE_URLS[:samuel_p_taylor].(day)
    page = Capybara::Node::Simple.new(Nokogiri::HTML(open(url)))
    availability = {}
    availability[day] = {}
    campsite_availability_rows = page.all('#calendar.items tbody tr')
    campsite_availability_rows.each do |row|
      next unless row.has_selector?('td.sn') && row.has_selector?('img') && /tent/.match(row.find('img')[:src])

      campsite_name = row.find('td.sn').text
      campsite_link = row.find('td.sn').find('.siteListLabel a')[:href]
      all_site_status_rows = row.all('td.status')

      availability[day][campsite_name] = []

      availability[day][campsite_name] << all_site_status_rows[0].text

      (length_of_stay_in_nights - 1).times do |i|
        availability[day][campsite_name] << all_site_status_rows[i + 1].text
      end

      if availability[day][campsite_name].all? { |status| status == 'A' }
        available_weekends << {
          date: day.strftime('%a %d %b %Y'),
          campsite_name: campsite_name,
          campsite_link: campsite_link,
          length_of_stay: length_of_stay_in_nights
        }
      end

      puts "Checking availability on #{day.strftime('%a %d %b %Y')}: site: #{campsite_name.gsub(/\s/, '')}, status: #{availability[day][campsite_name]}"
    end
  end

  available_weekends
end

def get_weekends(today, preferred_day)
  weekends = []

  today.next.upto(today.next + 365).each do |day|
    weekends << day if day.send("#{preferred_day}?")

    break if weekends.length >= 48
  end

  weekends
end

find_available_weekends(nil).each do |result_hash|
  puts "Campsite #{result_hash[:campsite_name].gsub(/\s/, '')} is available on #{result_hash[:date]} for #{result_hash[:length_of_stay]} nights! Book it now at #{result_hash[:campsite_link]}"
end