module BreakerBot
    class Break

        attr_accessor :title, :num_spots, :cost_per_spot, :event, :bot, :session, :add_reaction_event, :remove_reaction_event, :finished, :signed_up_users

        def initialize(bot, event, session)
            @bot = bot
            @event = event
            @session = session
            @finished = false
        end

        def start
            @session[:available_rooms] = break_channel_categories.concat(test_break_channel_categories)

            message = @event.author.dm 'What should the break be called? Tell me `cancel` at any time to cancel this process!'

            break_methods = [
                method(:get_name),
                method(:get_num_spots),
                method(:get_draft_format),
                method(:get_cost_per_spot),
                method(:get_channel_to_post)
            ]
            
            @event.author.pm.await! do |event|
                if break_methods.empty? || event.message.content.downcase == 'cancel'
                    event.respond('Goodbye!')
                    result = true
                else
                    next_break_method = break_methods.delete_at(0)
                    next_break_method.call(event)
                end
            end
            puts "end of start"
        end

        def test_break_channel_categories
            find_channels_in_catgories_with_string('spam', filter_categories_by_string('backstage')) || []
        end

        def break_channel_categories
            find_channels_in_catgories_with_string('announcements', filter_categories_by_string('room')) || []
        end

        def find_channels_in_catgories_with_string(filter_string, categories)
            @event.server.channels.select do |c|
                c.name.include?(filter_string) && c.type == Discordrb::Channel::TYPES[:text] && categories.any? { |cat| cat.id == c.parent_id }
            end
        end

        def filter_categories_by_string(filter_string)
            @event.server.channels.select do |c| 
                c.name.downcase.include?(filter_string) && c.type == Discordrb::Channel::TYPES[:category]
            end
        end

        def get_name(event)
            @session[:name] = event.message.content
            event.respond("Ok, how many spots are available in the break?")
        end
        
        def get_num_spots(event)
            @session[:num_spots] = event.message.content
            event.respond("Ok, how will the teams be assigned?")
        end

        def get_draft_format(event)
            @session[:assignment_format] = event.message.content
            event.respond("Ok, whats the cost per spot?")
        end
        
        def get_cost_per_spot(event)
            @session[:cost_per_spot] = event.message.content
            post_break_channels(event)
        end

        def post_break_channels(event)
            i=0
            response_text=["Ok, whats the channel to post the break in?"]
            @session[:available_rooms].each do |room|
                i+=1
                response_text.push("#{i}) ##{room.name}")
            end
            event.respond(response_text.join("\n"))
        end
        
        def get_channel_to_post(event)
            channel_to_post = @session[:available_rooms][event.message.content.to_i-1]
            server = @session[:server]
            
            if server.channels.find { |channel| channel.name == channel_to_post.name }
                @session[:channel] = channel_to_post
                @session[:state] = 3
                event.respond("Ok, should be good to go!")
                post_break
            else
                event.respond("Channel #{channel_to_post} not found. Try again!")
            end
            false
        end

        def end_posting(users, channel)
            puts "ending the posting"
            
            
            end_posting_text = []

            users.sort_by{ |u| u.username }.each do | user |
                next if user.current_bot?
                end_posting_text.push(user.mention)
            end

            embed = Discordrb::Webhooks::Embed.new(
                title: "** Break has filled! Get in payments if applicable **", 
                description: end_posting_text.join("\n"), 
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

            channel.send_embed('',embed)
        end

        def break_embed(session, users = [])
            break_text = []
            break_text.push("Number of Spots: #{@session[:num_spots]}")
            break_text.push("Cost per Spot: #{@session[:cost_per_spot]}")
            break_text.push("Team Assignment Format: #{@session[:assignment_format]}")
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
            
            @add_reaction_event = bot.reaction_add(emoji: 'suschicken', message: message.id) do |reaction_event|
                next true unless reaction_event.message.id == message.id
                message.edit('',break_embed(@session, message.reacted_with('suschicken:909224511310815333')))
                puts "in the event handler, @finished is #{@finished}"
                @finished = true unless message.reacted_with('suschicken:909224511310815333').length < @session[:num_spots].to_i
            end

            @remove_reaction_event = bot.reaction_remove(emoji: 'suschicken', message: message.id) do |reaction_event|
                next true unless reaction_event.message.id == message.id
                message.edit('',break_embed(@session, message.reacted_with('suschicken:909224511310815333')))
            end

            while @finished == false
                sleep(1)
            end

            bot.remove_handler(@remove_reaction_event)
            bot.remove_handler(@add_reaction_event)
            end_posting(message.reacted_with('suschicken:909224511310815333'), message.channel)
        end
    end
end