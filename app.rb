require 'sinatra'
require "sinatra/reloader" if development?
require 'twilio-ruby'
require 'httparty'
require 'giphy'
require 'open_weather'
require 'met_museum'

configure :development do
	require 'better_errors'
end


#https://hooks.slack.com/services/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

# a very basic sinatra setup
# with just one route 

enable :sessions

configure :development do
	require 'dotenv'
	Dotenv.load
  end

greetings = ['Hey there',"What's up!", "Good to see you", 'Welcome back!']
varied_greeting = ['Good Morning~',"Good Afternoon~", "Good Evening~"]
sercert_code = 'jyc'


get '/' do
  redirect '/about'
end

get '/about' do
  session["visits"] ||= 0 # Set the session to 0 if it hasn't been set before
  session["visits"] = session["visits"] + 1  # adds one to the current value (increments)
  time = Time.now 
  
  if time.hour >= 0 && time.hour < 12
	varied_g = varied_greeting[0]
  elsif  time.hour >= 12 && time.hour <18
	varied_g = varied_greeting[1]
  else 
	varied_g = varied_greeting[2]
  end 

  # deliver relevant greeting and info based on the user status
  if session['first_name'].nil?
		text = "#{varied_g}" + "<br/> I'm CoArtBot. Looks like you haven't signed up yet. Please sign up first."
  else
		text = "#{varied_g} <br>" + "#{greetings.sample} " + "<span>" + session['first_name'] + session['number'] + "!"
  end
	text += "<br/> You can explore several selected artworks daily by talking with me. <br>" + 
	"<br/>Total visits: " + session["visits"].to_s + 
	"<br/> #{ time.strftime("%Y-%m-%d %H:%M:%S")}"
  text
  
end

# signup with the secret code
get '/signup' do
	# check whether user signup or not.
	if not(session['first_name'].nil? || session['number'].nil?) 
		"Hi #{session['first_name']}, you have already signed up. Begin the arwork exploration journey with me."
	elsif check_code params[:code], sercert_code
		403
	else
		erb :"signup"
	end
end

# get the info from the input box
post "/signup" do
	if check_code params[:code], sercert_code
		403
	elsif params[:number].nil? || params[:first_name].nil?
		"You didn't enter all of the input fields."
	else
		client = Twilio::REST::Client.new ENV["TWILIO_ACCOUNT_SID"], ENV["TWILIO_AUTH_TOKEN"]
		message = "Hi " + params[:first_name] + ", welcome to CoArt-Bot! I can respond to who, what, where, when and why. If you're stuck, type help."

		session['first_name'] = params['first_name']
		session['number'] = params['number']

		  # this will send a message from any end point
		client.api.account.messages.create(
			from: ENV["TWILIO_FROM"],
			to: params[:number],
			body: message
		)
	end
	"Hi there, #{ params[:first_name]}.<br/>
	Your number is #{ params[:number]}"
end

get '/sms/incoming' do
	session["counter"] ||= 1
	body = params[:Body] || ""
	sender = params[:From] || ""
	session['last_intent'] ||= nil
  
	if session["counter"] == 1
		message = "Thank for your first message."
		media = "https://media.giphy.com/media/13ZHjidRzoi7n2/giphy.gif" 
		#media = 'https://www.metmuseum.org/-/media/images/visit/met-fifth-avenue/fifthave_teaser.jpg'
		#media = nil
	else
		message = determine_response body, sender
		#media = determine_media_response body
		media = nil
	end

	# Build a twilio response object 
	twiml = Twilio::TwiML::MessagingResponse.new do |r|
		r.message do |m|
		# add the text of the response
		  m.body( message )
		  # add media if it is defined
		  unless media.nil?
			m.media( media )
		  end
		end
	  end
	  
	# increment the session counter
	session["counter"] += 1
	  
	# send a response to twilio 
	content_type 'text/xml'
	twiml.to_s
end

# return needed information based on the user's input 
# get "/test/conversation" do
# 	if params[:Body].nil? || params[:From].nil? #check if parameters are blank
# 		response = "Sorry, I cannot understand what you're saying. <br>
# 						Try to use parameters called Body and From."
# 	else
# 		response = determine_response params[:Body]
# 	end
# 	response 
# end


# get "/test/giphy" do

# 	Giphy::Configuration.configure do |config|
# 	  config.api_key = ENV["GIPHY_API_KEY"]
# 	end
  
# 	results = Giphy.search( "lolz", { limit: 25 } )
  
# 	unless results.empty?
# 	  gif = results.sample
# 	  gif_url = gif.original_image.url
# 	  "I found this image: <img src='#{gif_url}' />"
  
# 	else
# 	  " I couldn't find a gif for that "
# 	end
  
# end


def determine_response body, sender 
		#keyword lists
		greeting_word = ['hey', 'hello', 'hi']
		greeting_response = ['I am good', "I'm fine.", "I'm pretty good.", 'pretty good.', "It's okay.", 'fine']
		confirm = ['Yes', 'I knew it.', 'Yes, I knew.', 'I have no idea', 'I do not know.', "I don't know"]
		who_word = ['who']
		what_word = ['what', 'help', 'features', 'functions', 'actions']
		where_word = ['where']
		when_word = ['when', 'time']
		why_word = ['why']
		joke_word = ['joke', 'jokes', 'story']
		fact_word = ['fact', 'facts']
		funny_word = ['lol', 'haha', 'hh', 'funny']

		body = body.downcase.strip
		res = ''
		jokes = IO.readlines("jokes.txt")
		facts = IO.readlines("facts.txt")
		met_url = 'https://www.metmuseum.org/-/media/images/visit/met-fifth-avenue/fifthave_teaser.jpg'

		if check_input body, greeting_word
			send_sms_to sender, "Hi🙌🏼, this is CoArt🤖! Really nice to see you here. My purpose is to help you generate ideas and get inspirations from artworks exploration."
			sleep(1)
			send_sms_to sender, "How are you?"
			#image_sms sender, "test", met_url 
			sleep(3)
			#send_sms_to sender, "How are you?"
			res += ""
			# res += "Hi there, this is CoArt! Really nice to see you here. My purpose is to help you generate ideas and get inspirations from artworks exploration."
		elsif check_input body, greeting_response
			session['last_intent'] = "museum_intro"
			res += "Okay, let's start from museum. Do you know the Metropolitan Museum of Art?"
		elsif session['last_intent'] == "museum_intro"   
		#elsif check_input body, confirm
			res += "The Metropolitan Museum of Art of New York City, colloquially 'the Met', is the largest art museum in the United States. \nWith 6,479,548 visitors to its three locations in 2019, it was the fourth most visited art museum in the world."
			image_sms sender, res, met_url 
			session['last_intent'] = 'intro_done'
		elsif check_input body, who_word
			res += "It's CoArt Bot created by Estelle Jiang. <br>
							If you want to know more about me, you can input 'fact' to the Body parameter."
		elsif check_input body, what_word
			res += "You can ask anything you are interested about me.<br>"
		elsif check_input body, where_word
			res += "I'm in Pittsburgh~<br>"
		elsif check_input body, when_word
			res += "The bot is made in Spring 2020.<br>"	   
		elsif check_input body, why_word
			res += "It was made for class project of 49714-pfop."
		elsif check_input body, fact_word
			res += facts.sample
		elsif check_input body, joke_word
			res += jokes.sample
		elsif check_input body, funny_word
			res += "Nice one right lol."
		elsif body == "weatherpittsburgh"
			options = { units: "metric", APPID: ENV["OPENWEATHER_API_KEY"] }
			response = OpenWeather::Current.city("Pittsburgh, PA", options)
			res = "Today's weather in pittsburgh is " + response['weather'][0]['main']
		elsif body == "sunflower"
			response = MetMuseum::Collection.new.search('akasaka', {limit: 1})
			#response = HTTParty.get('https://collectionapi.metmuseum.org/public/collection/v1/search?q=sunflowers')

		else
			# Sending unexpected answer to the Slack Channel
			res = send_to_slack body
			#message = error_response
		end
		res  
end 

def determine_media_response body

	q = body.to_s.downcase.strip
  
	Giphy::Configuration.configure do |config|
	  config.api_key = ENV["GIPHY_API_KEY"]
	end
  
	if q == "images"
	  giphy_search = "hello"
	elsif q == "fine"
	  giphy_search = 'https://www.metmuseum.org/-/media/images/visit/met-fifth-avenue/fifthave_teaser.jpg'
	end
	return giphy_search

	# unless giphy_search.nil?
	#   results = Giphy.search( giphy_search, { limit: 25 } )
	#   unless results.empty?
	# 	gif = results.sample
	# 	gif_url = gif.original_image.url
	#   end
	#   return gif_url
	#  end 

	 nil
  end

def send_sms_to send_to, message
client = Twilio::REST::Client.new ENV["TWILIO_ACCOUNT_SID"], ENV["TWILIO_AUTH_TOKEN"]
client.api.account.messages.create(
	from: ENV["TWILIO_FROM"],
	to: send_to,
	body: message
)
end

def image_sms send_to, message, media
	client = Twilio::REST::Client.new ENV["TWILIO_ACCOUNT_SID"], ENV["TWILIO_AUTH_TOKEN"]
	client.api.account.messages.create(     
		from: ENV["TWILIO_FROM"],      
		to: send_to,     
		body: message,    
		media_url:media   
	)
	# client = Twilio::REST::Client.new ENV["TWILIO_ACCOUNT_SID"], ENV["TWILIO_AUTH_TOKEN"]
	# message = client.messages.create(
	# 				 body: 'Hello there!',
	# 				 from: ENV["TWILIO_FROM"],
	# 				 media_url: ['https://demo.twilio.com/owl.png'],
	# 				 to: sender
	# 			   )	
end 


# method to check user' input
def check_input body, word_set
	word_set.each do |word|
		if body == word.downcase 
			return true
		end
  	end
	return false
end

# check whether user signup with a sercert code.
def check_code code, sercert
	return code.nil? || code != sercert
end 

# 
def send_to_slack message

	slack_webhook = ENV['SLACK_WEBHOOK']
  
	formatted_message = "*Recently Received:*\n"
	formatted_message += "#{message} "
	HTTParty.post slack_webhook, body: {text: formatted_message.to_s, username: "CoArtBot" }.to_json, headers: {'content-type' => 'application/json'}
  
  end

error 403 do
 "Access Forbidden"
end
