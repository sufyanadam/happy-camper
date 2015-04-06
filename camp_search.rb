require 'date'
require 'open-uri'
require 'capybara'
require 'pry'

CAMPSITE_URLS = {
  samuel_p_taylor:      ->(date) { "http://www.reserveamerica.com/campsiteCalendar.do?page=matrix&calarvdate=#{date.strftime('%m/%d/%Y')}&contractCode=CA&parkId=120081"  },
  kirby_cove:           ->(date) { "http://www.reserveamerica.com/campsiteCalendar.do?page=matrix&calarvdate=#{date.strftime('%m/%d/%Y')}&contractCode=NRSO&parkId=70972" },
  mt_tamalpais_sp:      ->(date) { "http://www.reserveamerica.com/campsiteCalendar.do?page=matrix&calarvdate=#{date.strftime('%m/%d/%Y')}&contractCode=CA&parkId=120063"  },
  anthony_chabot:       ->(date) { "http://www.reserveamerica.com/campsiteCalendar.do?page=matrix&calarvdate=#{date.strftime('%m/%d/%Y')}&contractCode=EB&parkId=110004"  },
  mt_diablo:            ->(date) { "http://www.reserveamerica.com/campsiteCalendar.do?page=matrix&calarvdate=#{date.strftime('%m/%d/%Y')}&contractCode=CA&parkId=120061"  },
  sugarloaf_ridge:      ->(date) { "http://www.reserveamerica.com/campsiteCalendar.do?page=matrix&calarvdate=#{date.strftime('%m/%d/%Y')}&contractCode=CA&parkId=120092"  },
  half_moon_bay:        ->(date) { "http://www.reserveamerica.com/campsiteCalendar.do?page=matrix&calarvdate=#{date.strftime('%m/%d/%Y')}&contractCode=CA&parkId=120039"  },
  del_valle:            ->(date) { "http://www.reserveamerica.com/campsiteCalendar.do?page=matrix&calarvdate=#{date.strftime('%m/%d/%Y')}&contractCode=EB&parkId=110003"  },
  bothenapa_valley_sp:  ->(date) { "http://www.reserveamerica.com/campsiteCalendar.do?page=matrix&calarvdate=#{date.strftime('%m/%d/%Y')}&contractCode=CA&parkId=120011"  },
  portola_redwoods_sp:  ->(date) { "http://www.reserveamerica.com/campsiteCalendar.do?page=matrix&calarvdate=#{date.strftime('%m/%d/%Y')}&contractCode=CA&parkId=120073"  },
  butano_sp:            ->(date) { "http://www.reserveamerica.com/campsiteCalendar.do?page=matrix&calarvdate=#{date.strftime('%m/%d/%Y')}&contractCode=CA&parkId=120013"  }
}

MAX_WEEKENDS_COUNT = 30

def find_available_weekends(campsite_url, preferred_day: :friday, length_of_stay_in_nights: 2)
  today = Date.today
  weekends = get_weekends(today, preferred_day)
  available_weekends = []

  weekends.each do |day|
    page = Capybara::Node::Simple.new(Nokogiri::HTML(open(campsite_url.(day))))
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

    break if weekends.length >= MAX_WEEKENDS_COUNT
  end

  weekends
end

def format_park_name(park_name)
  park_name.to_s.gsub(/(^[a-z]{1})|(_[a-z]{1})/) { |matched| matched.gsub('_', ' ').upcase}.gsub(/Sp\Z/, 'SP')
end

puts "What park would you like to search availability for?"
puts "Known parks:\n"
longest_name_length = CAMPSITE_URLS.keys.max_by(&:size).size

CAMPSITE_URLS.keys.each_with_index do |park, index|
  puts <<-PARK_MAP
    #{format_park_name(park).ljust(longest_name_length)} #{index.to_s.rjust(3)}
  PARK_MAP
end

print ">"
park_to_search = STDIN.gets.chomp.to_i
park_key = CAMPSITE_URLS.keys[park_to_search]
url = CAMPSITE_URLS[park_key]

puts "\nSearching for available campsites at #{format_park_name(park_key)} park"

find_available_weekends(url).each do |result_hash|
  puts "Campsite #{result_hash[:campsite_name].gsub(/\s/, '')} is available on #{result_hash[:date]} for #{result_hash[:length_of_stay]} nights! Book it now at #{result_hash[:campsite_link]}"
end
