require 'sinatra'
require "sinatra/reloader" if development?
require 'twilio-ruby'
require 'httparty'
require 'giphy'
require 'open_weather'
require 'met_museum'
require 'json'

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

def determine_response body, sender 
		#keyword lists
		greeting_word = ['hey', 'hello', 'hi']
		greeting_response = ['I am good', "I'm fine.", "I'm pretty good.", 'pretty good.', "It's okay.", 'fine', 'Good']
		confirm = ['Yes', 'I knew it.', 'Yes, I knew.', 'I have no idea', 'I do not know.', "I don't know"]
		next_move = ['next topic', 'next keyword', 'new topic', 'new']
		more_about = ['more info about this one', 'I want more', 'send me more info', 'send me more', 'more']
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
		met_url = ''
		session['info_table'] ||= nil

		if check_input body, greeting_word
			send_sms_to sender, "Hi 🙌🏼, this is CoArt 🤖! Really nice to see you here. My purpose is to help you generate ideas and get inspirations from artworks exploration."
			sleep(1)
			send_sms_to sender, "How are you?"
			sleep(3)
			res += ""
		elsif check_input body, greeting_response
			session['last_intent'] = "museum_intro"
			res += "Okay, let's start from museum 🎫🏛. Do you know the Metropolitan Museum of Art?"
		elsif session['last_intent'] == "museum_intro"   
		#elsif check_input body, confirm
			message = "The Metropolitan Museum of Art of New York City, colloquially 'the Met', is the largest art museum in the United States. \nWith 6,479,548 visitors to its three locations in 2019, it was the fourth most visited art museum in the world."
			met_url = 'https://www.metmuseum.org/-/media/images/visit/met-fifth-avenue/fifthave_teaser.jpg'
			image_sms sender, message, met_url 
			sleep(8)
			send_sms_to sender, "To help you gain insiprations, I will just collect art pieces from the MET!🥳"
			sleep(5)
			res += "Are you ready to discover something fun and new with me?"
			session['last_intent'] = 'intro_done'
		elsif session['last_intent'] == "intro_done"
			send_sms_to sender, "Using one word or emoji to let me know what you have in mind and what topic you want to explore." 
			sleep(3)
			send_sms_to sender, "For example, you might think about animal at this moment, then, what animal specifically? You can send me 'monkey'/🐒, 'cat'/🐈, or 'elephant'/🐘." 
			session['last_intent'] = "begin_explore"
		elsif check_input body, who_word
			res += "It's CoArt Bot created by Estelle Jiang. \nIf you want to know more about me, you can input 'fact' to the Body parameter."
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
		# elsif check_input body, joke_word
		# 	res += jokes.sample
		# elsif check_input body, funny_word
		# 	res += "Nice one right lol."
		# elsif body == "weatherpittsburgh"
		# 	options = { units: "metric", APPID: ENV["OPENWEATHER_API_KEY"] }
		# 	response = OpenWeather::Current.city("Pittsburgh, PA", options)
		# 	res = "Today's weather in pittsburgh is " + response['weather'][0]['main']
		elsif session['last_intent'] == "begin_explore"
			info = artwork_explorer body 
			message = "Check what I got for you 🎁📖! This art piece is a " + info['object'] + " and it’s called " + info['title'] + ". Right now, it belongs to " + info['department'] + " department at the MET. It was created by " + info['artist'] + " (" + info['bio'] + "). As you can see, the medium for this art piece is " + info['medium'] + ". 🗂"
			image_sms sender, message, info['image']
			sleep(10)
			send_sms_to sender, "Sounds good to you? Let me know whether you want to know more about this artwork, or you want to explore some new topic."
			session['last_intent'] = 'continue_explore'
			session['info_table'] = info.to_json
			res += session['info_table']
		elsif check_input body, next_move
			res += "Sure, what else you want to explore?"
			session['last_intent'] = 'begin_explore'
		elsif check_input body, more_about
			#info_cont = JSON.parse(session['info_table'])
			#res += info_cont['artist_url']
			res += session['info_table']
			# if info['artist_url'] != ''
			# 	res += "I knew! It's a really good one. You can go to " + info['artist_url'] + "to take a closer look at this artist. Also, please check out " + info['met_url']
			# else 
			# 	res += "I knew! It's really amazing. You can go to " + info['met_url'] + " to check out more information and relevant pieces."
			# end
		else
			# Sending unexpected answer to the Slack Channel
			res = send_to_slack body
			#message = error_response
		end
		res  
end 

# def determine_media_response body

# 	q = body.to_s.downcase.strip
  
# 	Giphy::Configuration.configure do |config|
# 	  config.api_key = ENV["GIPHY_API_KEY"]
# 	end
  
# 	if q == "images"
# 	  giphy_search = "hello"
# 	elsif q == "fine"
# 	  giphy_search = 'https://www.metmuseum.org/-/media/images/visit/met-fifth-avenue/fifthave_teaser.jpg'
# 	end
# 	return giphy_search

# 	# unless giphy_search.nil?
# 	#   results = Giphy.search( giphy_search, { limit: 25 } )
# 	#   unless results.empty?
# 	# 	gif = results.sample
# 	# 	gif_url = gif.original_image.url
# 	#   end
# 	#   return gif_url
# 	#  end 

# 	 nil
#   end

def artwork_explorer body
	table = {}
	response = MetMuseum::Collection.new.search(body, {limit: 10}) 
	art = response.sample
	table['object'] = art['objectName'].downcase
	table['title'] = art['title']
	table['department'] = art['department']
	table['artist'] = art['artistDisplayName']
	table['bio'] = art['artistDisplayBio']
	table['medium'] = art['medium'].downcase
	table['dimensions'] = art['dimensions']
	table['image'] = art['primaryImageSmall']
	table['artist_url'] = art['artistWikidata_URL']
	table['met_url'] = art['objectURL']

	return table
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
