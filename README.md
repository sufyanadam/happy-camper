# Find a campsite, be happy

  For the next 30 weekends from today, check if any campsites are available.
  You have the option to provide the site id of a specific site at the park if
  you want to check availability of that site only. Otherwise, all available
  tent sites will be checked for availability on each weekend up to the 30th
  weekend from today.

# Why?

  * Don't have time to sit and click around to see only two weeks
    worth of availability for campsites at certain parks when searching
    for a good campsite. Especially when weekends are almost always
    fully booked up at certain parks.

  * No public access to a legit API.

  * Convenient, saves time. I can now find what campsites are available at
    a few parks within 60 seconds, as opposed to 60 minutes.

# Usage

  * `git clone https://github.com/sufyanadam/happy-camper`
  * install phantomjs (`brew install phantomjs` on mac)
  * `bundle install`
  * `ruby camp_search.rb`
  * Follow prompts

### Example
  * Find available campsites at the Samuel P Taylor park over the
    next 30 weekends from today:

  ![usage](https://raw.githubusercontent.com/sufyanadam/happy-camper/master/happy-camper.gif)

# Disclaimer

  I am not responsible for anything as a result of your use of this script or anything related to this script.
  Use at your own risk. The intent and purpose of this script is for educational purposes only.