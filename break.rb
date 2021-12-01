module BreakerBot
    class Break

        attr_accessor :title, :num_spots, :cost_per_spot, :event, :bot, :session

        def initialize(bot, event, session)
            @bot = bot
            @event = event
            @session = session
        end

        def start
            message = @event.author.dm 'What should the break be called?'
            
            @event.author.pm.await! do |event|
                get_name(event)
                true
            end

            @event.author.pm.await! do |event|
                get_num_spots(event)
                true
            end

            @event.author.pm.await! do |event|
                get_cost_per_spot(event)
                true
            end

            @event.author.pm.await! do |event|
                get_channel_to_post(event)
                true
            end
        end

        def break_channel_categories(server)
            server.channels.select{ |c| c.name.downcase.include?('backstage') && c.type == Discordrb::Channel::TYPES[:category] }
        end
        
        def break_announcement_rooms(server)
            server.channels.select{ |c| c.name.include?('spam') && c.type == Discordrb::Channel::TYPES[:text] && break_channel_categories(server).any? { |cat| cat.id == c.parent_id } }
        end
        
        # def get_break_details (bot, session, event)
        #     pp(@session)
        #     case @session[:state]
        #     when 0
        #         get_name(@bot, @session, event)
        #     when 1
        #         get_num_spots(@bot, @session, event)
        #     when 2
        #         get_cost_per_spot(@bot, @session, event)
        #     when 3
        #         get_channel_to_post(@bot, @session, event)
        #     else
        #         puts "you sure you did this right? @session state is #{@session['state']}"
        #     end
        # end
        
        def get_name(event)
            @session[:name] = event.message.content
            @session[:state] = 1
            event.respond("Ok, how many spots are available in the break?")
        end
        
        def get_num_spots(event)
            @session[:num_spots] = event.message.content
            @session[:state] = 2
            event.respond("Ok, whats the cost per spot?")
        end
        
        def get_cost_per_spot(event)
            pp(@session)
            @session[:cost_per_spot] = event.message.content
            @session[:state] = 3
            response_text=["Ok, whats the channel to post the break in?"]
            i=0
            @session[:available_rooms].each do |room|
                i+=1
                response_text.push("#{i}) ##{room.name}")
            end
            event.respond(response_text.join("\n"))
        end
        
        def get_channel_to_post(event)
            channel_to_post = @session[:available_rooms][event.message.content.to_i-1]
            server = @session[:server]
            puts "#{channel_to_post.name} was selected"
            if server.channels.find { |channel| channel.name == channel_to_post.name }
                @session[:channel] = channel_to_post
                @session[:state] = 3
                event.respond("Ok, should be good to go!")
                post_break
                pp(@session)
            else
                event.respond("Channel #{channel_to_post} not found. Try again!")
            end
        end

        def break_embed(session, users = [])
            break_text = []
            break_text.push("Number of Spots: #{@session[:num_spots]}")
            break_text.push("Cost per Spot: #{@session[:cost_per_spot]}")
            break_text.push("\n")
            break_text.push("Click the suschicken to sign up for the break!")
            break_text.push("\n Sign up list: \n") unless users.length == 0 
            users.sort_by{ |u| u.username }.each do | user |
                next if user.current_bot?
                break_text.push(user.username)
            end

            embed = Discordrb::Webhooks::Embed.new(
                title: "** #{@session[:name]}**", 
                description: break_text.join("\n"), 
                url: nil,
                timestamp: nil, 
                color: "0000FF", 
                footer: nil, 
                image: nil, 
                thumbnail: Discordrb::Webhooks::EmbedImage.new(url: 'https://cdn.discordapp.com/attachments/298833688056299530/908431888866213908/breakernet_discord_logo_test_1.png'), 
                video: nil, 
                provider: nil, 
                author: nil, 
                fields: []
            )
        end
        
        def post_break
            message = @session[:channel].send_embed('',break_embed(@session, []))
            message.create_reaction('suschicken:909224511310815333')
            
            bot.reaction_add(emoji: 'suschicken', message: message.id) do |reaction_event|
                next true unless reaction_event.message.id == message.id
                message.edit('',break_embed(@session, message.reacted_with('suschicken:909224511310815333')))
            end

            bot.reaction_remove(emoji: 'suschicken', message: message.id) do |reaction_event|
                next true unless reaction_event.message.id == message.id
                message.edit('',break_embed(@session, message.reacted_with('suschicken:909224511310815333')))
            end
        end
    end
end