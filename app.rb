require 'sinatra'
require "sinatra/reloader" if development?
require 'twilio-ruby'




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
		message = "Hi" + params[:first_name] + ", welcome to BotName! I can respond to who, what, where, when and why. If you're stuck, type help."

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

# can be used if no sercert code is required.
# get '/signup/:first_name/:number' do
# 	session['first_name'] = params['first_name']
# 	session['number'] = params['number']
# 	"Hi there, #{ params[:first_name]}.<br/>
# 	Your number is #{ params[:number]}"
# end

get '/incoming/sms' do
  403
end

# return needed information based on the user's input 
get "/test/conversation" do
	if params[:Body].nil? || params[:From].nil? #check if parameters are blank
		response = "Sorry, I cannot understand what you're saying. <br>
						Try to use parameters called Body and From."
	else
		response = determine_response params[:Body]
	end
	response 
end

def determine_response body 
		#keyword lists
		greeting_word = ['hey', 'hello', 'hi']
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
		if check_input body, greeting_word
			res += "Hi there, this app will help you explore the popular artworks everyday.<br>"
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
			res += "It was made for class project of 49714-pfop.<br>"
		elsif check_input body, fact_word
			res += facts.sample
		elsif check_input body, joke_word
			res += jokes.sample
		elsif check_input body, funny_word
			res += "Nice one right lol."
		else
			res += "Sorry, your input cannot be understood by the bot.<br>
							Try using two parameters called Body and From."
		end
		res  
end 

# method to check user' input
def check_input body, word_set
	word_set.each do |word|
		if body == word 
			return true
		end
  	end
	return false
end

# check whether user signup with a sercert code.
def check_code code, sercert
	return code.nil? || code != sercert
end 


error 403 do
 "Access Forbidden"
end
