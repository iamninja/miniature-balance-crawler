require "sinatra"
require "nokogiri"
require "mechanize"
require "json"
require "./credentials"

### Crawler

LOGIN_URL = "https://www.vodafone.gr/portal/client/idm/loginForm.action?null"
PROFILE_URL = "https://www.vodafone.gr/portal/client/idm/loadPrepayUserProfile.action?scrollanchor=0"

# USERNAME = ""
# PASSWORD = ""

class VodafoneCrawler
	attr_reader :username, :phoneNumber, :moneyBalance, :dataBalance

	def initialize
		@phoneNumber = ""
		@balanceEuro = 0
		@balanceCents = 0
		@moneyBalance = 0
		@dataBalance = -1
		@username = USERNAME
		@password = PASSWORD

		# Initialize a mechanize browser
		@browser = Mechanize.new { |agent|
			agent.user_agent_alias = "Mac Safari"
		}
	end

	def login
		@browser.get(LOGIN_URL) do |page|
			puts "Logging in as #{USERNAME}..."
			form = page.forms.first

			form['username'] = @username
			form['password'] = @password
			logged_page = form.submit
			logged_page.encoding = 'utf-8'
			puts "...logged in"
		end
	end

	def crawl_balance
		@browser.get(PROFILE_URL) do |page|
			if page.at('h1').text.strip == "Έχεις αποσυνδεθεί από το My account"
				puts "Logged out, need to login again"
				login
			end
			puts "Retrieving data..."
			# User info
			@phoneNumber = page.at('div.ppMyProfileTitle span').text

			# Money balance info
			@balanceEuro = page.at('div.firstRow2').text.strip.to_i
			@balanceCents = page.at('div.firstRow2 span').text.strip
			@moneyBalance = "#{@balanceEuro}.#{@balanceCents}".to_f

			# Data balance info
			balances = page.search('.table-sort td.toggler .cc-remaining')
			dataBalanceArray = Array.new
			balances.each do |node|
				if node.content.include? 'MB'
					dataBalanceArray << node.first_element_child.text.strip.to_i
				end
			end
			@dataBalance = dataBalanceArray.inject(0, :+)
			puts "...data retrieved"
		end
	end
end

### Sinatra server

crawler = VodafoneCrawler.new
crawler.login

set :server, 'thin'
set :port, 7777
set :environment, :production

get '/info' do

	return_message = {}
	# Get the data
	crawler.crawl_balance

	return_message[:username] = crawler.username
	return_message[:phoneNumber] = crawler.phoneNumber
	return_message[:moneyBalance] = crawler.moneyBalance
	return_message[:dataBalance] = crawler.dataBalance
	return_message.to_json
end
