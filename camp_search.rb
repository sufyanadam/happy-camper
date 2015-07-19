require 'yaml'
require 'date'
require 'open-uri'
require 'capybara'

PARKS = {
  samuel_p_taylor_sp:  {contract_code: 'CA',   park_id: '120081' },
  kirby_cove:          {contract_code: 'NRSO', park_id: '70972'  },
  mt_tamalpais_sp:     {contract_code: 'CA',   park_id: '120063' },
  anthony_chabot:      {contract_code: 'EB',   park_id: '110004' },
  mt_diablo:           {contract_code: 'CA',   park_id: '120061' },
  sugarloaf_ridge:     {contract_code: 'CA',   park_id: '120092' },
  half_moon_bay:       {contract_code: 'CA',   park_id: '120039' },
  del_valle:           {contract_code: 'EB',   park_id: '110003' },
  bothenapa_valley_sp: {contract_code: 'CA',   park_id: '120011' },
  portola_redwoods_sp: {contract_code: 'CA',   park_id: '120073' },
  butano_sp:           {contract_code: 'CA',   park_id: '120013' }
}.merge(YAML.load(File.read('parks.yml')))

DAY_OF_WEEK = %i[friday saturday sunday monday tuesday wednesday thursday]

PARK_AVAILABILITY_URL = ->(contract_code, park_id) { ->(date) { "http://www.reserveamerica.com/campsiteCalendar.do?page=matrix&calarvdate=#{date.strftime('%m/%d/%Y')}&contractCode=#{contract_code}&parkId=#{park_id}" } }

SPECIFIC_SITE_AVAILABILITY_URL = ->(park_name, contract_code, park_id, site_id) { ->(date) { "http://www.reserveamerica.com/camping/#{park_name}/r/campsiteDetails.do?arvdate=#{date.strftime('%m/%d/%Y')}&contractCode=#{contract_code}&parkId=#{park_id}&siteId=#{site_id}" } }

MAX_WEEKENDS_COUNT = 30

def find_available_weekends(campsite_url, preferred_day: :friday, length_of_stay_in_nights: 2)
  today = Date.today
  weekends = get_weekends(today, preferred_day)
  available_weekends = []

  weekends.each do |day|
    page = Capybara::Node::Simple.new(Nokogiri::HTML(open(campsite_url.(day))))
    availability = {}
    availability[day] = {}

    if page.has_selector?('td#avail1')
      campsite_name = page.find('.siteTile').text
      campsite_link = campsite_url.(day).gsub('http://www.reserveamerica.com', '')
      availability[day][campsite_name] = []

      length_of_stay_in_nights.times do |i|
        availability[day][campsite_name] << page.find("td#avail#{i + 1}")[:title]
      end

      if availability[day][campsite_name].all? { |status| status == 'Available' }
        available_weekends << {
          date: day.strftime('%a %d %b %Y'),
          campsite_name: campsite_name,
          campsite_link: campsite_link,
          length_of_stay: length_of_stay_in_nights
        }
      end

      puts "Checking availability on #{day.strftime('%a %d %b %Y')}. Status: #{availability[day][campsite_name]}"

      next
    end
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
  park_name.to_s.
    gsub(/(^[a-z]{1})|(_[a-z]{1})|(-[a-z])/) { |matched| matched.gsub('_', ' ').upcase }.
    gsub(/Sp\Z/, 'SP').
    gsub('-', ' ')
end

def get_park_info_from(url)
  park_name, contract_code, park_id = url.match(/camping\/(.+)\/r.+contractCode=(.+).+parkId=(.+)\b/).captures
  return {} if [park_name, contract_code, park_id].any? { |item| item.nil? }

  {park_name => {contract_code: contract_code, park_id: park_id}}
end

puts "What park would you like to search availability for?"
puts "Known parks:\n\n"
longest_name_length = PARKS.keys.max_by(&:size).size

PARKS.keys.each_with_index do |park, index|
  puts <<-PARK_MAP
    #{format_park_name(park).ljust(longest_name_length)} #{index.to_s.rjust(3)}
  PARK_MAP
end

puts sprintf "    %s %s", "Other".ljust(longest_name_length), PARKS.keys.length.to_s.rjust(3)

print "\n> "
park_to_search = STDIN.gets.chomp.to_i
park_key = PARKS.keys[park_to_search]

if park_key.nil?
  puts "Enter the reserve america url of the campsite you're interested in. It should look like: http://www.reserveamerica.com/camping/samuel-p-taylor-sp/r/campgroundDetails.do?contractCode=CA&parkId=120081"

  park_info = nil

  user_url, park_info = loop do
    print "\n>"
    url = STDIN.gets.chomp
    info = get_park_info_from url

    break [url, info] unless info.empty?

    puts "Looks like the the url you gave me wasn't quite what I was looking for. Give me the url from your browser after searching for camping availability for any date at your desired park on reserveamerica.com"
  end

  return if PARKS.keys.include?(park_info.keys.first)

  File.open('parks.yml', 'a') do |f|
    f.write park_info.to_yaml[4..-1]
  end

  PARKS.merge!(park_info)
  park_key = PARKS.keys[park_to_search]
end

park_contract_code = PARKS[park_key][:contract_code]
park_id = PARKS[park_key][:park_id]
print "\nHow many nights are you looking to camp for? (default: 2) >"
length_of_stay_in_nights = STDIN.gets.chomp.to_i
length_of_stay_in_nights = 2 if length_of_stay_in_nights < 1
puts "\nWhat day of the week would you like to search availability for? (default: Friday):"
DAY_OF_WEEK.each_with_index do |day, index|
  puts "#{day.to_s.ljust(9)} #{index.to_s.rjust(3)}"
end
print "> "
preferred_day = DAY_OF_WEEK[STDIN.gets.chomp.to_i]
print "\nDo you already have your eye on a specific site at #{format_park_name(park_key)}?(y/n) > "
specific_site = STDIN.gets.chomp
if specific_site == 'y' || specific_site == 'Y'
  print "Enter the site id of the specific site you have in mind: "
  site_id = STDIN.gets.chomp
end
if site_id
  url = SPECIFIC_SITE_AVAILABILITY_URL.(park_key.to_s, park_contract_code, park_id, site_id)
  puts "\nSearching for availability of site #{site_id} at #{format_park_name(park_key)} park...\n\n"
else
  url = PARK_AVAILABILITY_URL.(park_contract_code, park_id)
  puts "\nSearching for available campsites at #{format_park_name(park_key)} park...\n\n"
end

available_weekends = find_available_weekends(url, preferred_day: preferred_day, length_of_stay_in_nights: length_of_stay_in_nights)

if available_weekends.empty?
  puts "\n\nNo available weekends to book :("
  exit
end

available_weekends.each do |result_hash|
  puts "\n\nCampsite #{result_hash[:campsite_name].gsub(/\s/, '').gsub(/Map/,'')} is available on #{result_hash[:date]} for #{result_hash[:length_of_stay]} nights! Book it now at http://reserveamerica.com#{result_hash[:campsite_link]}\n\n"
end
