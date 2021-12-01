module BreakerBot
    class Giveaway
        attr_accessor :bot, :event, :entrants, :prize, :session, :num_winners, :duration, :channel

        def initialize(bot, event, session)
            @bot = bot
            @event = event
            @session = session
            @entrants = []
        end

        def start
            session[:available_rooms] = giveaway_rooms(event.server) 
            get_prize
            get_num_winners
            get_duration
            get_channel_to_post
            post_giveaway
        end

        def get_prize
            event.respond('What are you giving away?')
            event.message.await! do |e|
                @prize = e.message.content
                true
            end
        end

        def get_num_winners
            event.respond('How many winners for this giveaway?')
            event.message.await! do |e|
                @num_winners = e.message.content.to_i
                true
            end
        end

        def get_duration
            event.respond('How long should this giveaway last in seconds?')
            event.message.await! do |e|
                @duration = e.message.content.to_i
                true
            end
        end

        def get_channel_to_post
            response_text=["Ok, whats the channel to post the giveaway in?"]
            i=0
            session[:available_rooms].each do |room|
                i+=1
                response_text.push("#{i}) ##{room.name}")
            end
            event.respond(response_text.join("\n"))
            event.message.await! do |e|
                @channel = session[:available_rooms][event.message.content.to_i-1]
                true
            end
        end

        def giveaway_rooms(server)
            server.channels.select{ |c| c.name.include?('giveaway') && c.type == Discordrb::Channel::TYPES[:text] }
        end

        def post_giveaway
            giveaway_text = ["**Giveaway**"]
            giveaway_text.push("Giveaway Prize: #{@prize}")
            giveaway_text.push("Number of Winners: #{@num_winners}")
            giveaway_text.push("Duration: #{@duration}")
            giveaway_text.push("Click on the suschicken to enter giveaway!")
            message = bot.send_message(@channel, giveaway_text.join("\n"))
            message.create_reaction('suschicken:909224511310815333')
            sleep(@duration)
            reactions = message.reacted_with('suschicken:909224511310815333')
            pp(reactions)
            pp(reactions.delete_if { |reaction| reaction.username == "BreakerBot" })
            winner = reactions.delete_if { |reaction| reaction.username == "BreakerBot" }.sample
            bot.send_message(@channel, "**WINNER IS #{winner.username}**")
        end        
    end
end