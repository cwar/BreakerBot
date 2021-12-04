module BreakerBot
    class Draft
        attr_accessor :bot, :event, :drafters, :teams, :session, :num_spots, :snaked_order

        def initialize(bot, event, session)
            @bot = bot
            @event = event
            @session = session
            @drafters = []
            @snaked_order = []

            setup_events
        end

        def setup_events
            @bot.message(with_text: '!teams') do |event|
                embed_available_teams(event)
            end

            @bot.message(with_text: '!results') do |event|
                event.respond(print_drafted_teams(@teams).join("\n"))
            end
        end

        def draft_channel_categories(server)
            server.channels.select{ |c| c.name.downcase.include?('room') && c.type == Discordrb::Channel::TYPES[:category] }
        end

        def draft_chat_rooms(server)
            server.channels.select{ |c| c.name.include?('chat') && c.type == Discordrb::Channel::TYPES[:text] && draft_channel_categories(server).any? { |cat| cat.id == c.parent_id } }
        end

        def embed_available_teams(event)
            event.send_embed do |embed|
                embed.title = 'Available Teams:'
                embed.thumbnail = Discordrb::Webhooks::EmbedImage.new(url: 'https://cdn.discordapp.com/attachments/298833688056299530/908431888866213908/breakernet_discord_logo_test_1.png')
                embed.color = "0000FF"
                embed.description = print_available_teams(@teams).join("\n")
            end
        end

        def print_draft_order(event)
            draft_order_array = []
            i=0
            @drafters.each do |drafter|
                i+=1
                draft_order_array.push("##{i} - #{drafter.username}")
            end
            event.send_embed do |embed|
                embed.title = 'Draft Order:'
                embed.thumbnail = Discordrb::Webhooks::EmbedImage.new(url: 'https://cdn.discordapp.com/attachments/298833688056299530/908431888866213908/breakernet_discord_logo_test_1.png')
                embed.color = "0000FF"
                embed.description = draft_order_array.join("\n")
            end
        end

        def drafter_event(drafter_event)
            
            drafter_ids = drafter_event.message.content.tr('@','').tr('!','').tr('<','').tr('>','').split(',')
            
            drafter_ids.each do |id|
                @drafters.push(event.server.member(id))
            end
            
            # drafter_event.respond("drafters are:")

            # print_draft_order(event)

            drafter_event.respond("randomizing order...")

            rand = Random.new

            times_to_shuffe = rand(2..12)

            drafter_event.respond("#{times_to_shuffe} times, wait until all done")

            times_to_shuffe.times do
                @drafters.shuffle!

                message = print_draft_order(event)
                sleep(3)
                message.delete
            end

            drafter_event.respond("Final draft order is:")
            print_full_draft_order(event)
        end

        def print_full_draft_order(event)
            draft_order_array = []
            snaked_order= @drafters.concat(@drafters.reverse)
            pp(snaked_order)
            i=0
            @num_spots.times do
                @snaked_order.push(snaked_order[i % snaked_order.length])
                draft_order_array.push("##{i+1} - #{snaked_order[i % snaked_order.length].username}")
                i+=1
            end
            event.send_embed do |embed|
                embed.title = 'Draft Order:'
                embed.thumbnail = Discordrb::Webhooks::EmbedImage.new(url: 'https://cdn.discordapp.com/attachments/298833688056299530/908431888866213908/breakernet_discord_logo_test_1.png')
                embed.color = "0000FF"
                embed.description = draft_order_array.join("\n")
            end
        end

        def print_available_teams(team_list)
            team_list.select { |t| t[:drafted_by].nil? }.collect{ |x| x[:display_name] }.unshift('Available Teams:')
        end

        def print_drafted_teams(team_list)
            team_list.select { |t| !t[:drafted_by].nil? }.sort_by{ |y| y[:round_drafted] }.collect{ |x| "#{x[:round_drafted]} - #{x[:display_name]} (#{x[:drafted_by].username})" }.unshift('Current Results:')
        end

        def start
            event.respond('How many spots in the draft?')
            event.message.await! do |spots_event|
               @num_spots = spots_event.message.content.to_i 
               true
            end
            event.respond('Please enter the list of drafters (one line separated by commas, use the @discordname)')
            
            event.message.await! do |drafter_event|
                drafter_event(drafter_event)
                true
            end

            @drafters.concat(@drafters.reverse)
            @teams = mlb_draft_teams
            embed_available_teams(event)

            i=0
            while @snaked_order.length > 0
                i+=1
                drafting_user = get_next_drafting_user
                event.respond("#{drafting_user.mention} turn to pick!")
                drafting_user.await!(contains: '!pick') do |e|
                    pick = e.message.content.delete_prefix('!pick ')
                    pp(pick)
                    pick_team(drafting_user, pick, e, i)
                end
            end
        end

        def get_next_drafting_user
            @snaked_order.delete_at(0)
        end

        def pick_team(user, pick, event, i)
            picked_team = @teams.select{ |team| team[:drafted_by].nil? && team[:display_name].downcase.include?(pick.downcase) }
            result = false
            pp(picked_team)
            pp(picked_team.length)
            if picked_team.length > 1
                event.respond("Be more specific, #{pick} matched #{picked_team.length} teams.")
            elsif picked_team.length == 1
                pp(picked_team)
                puts "pick: #{pick}"
                event.respond("#{user.mention} picks #{picked_team[0][:display_name]}")
                picked_team[0][:drafted_by] = user
                picked_team[0][:round_drafted] = i
                puts "picked_team: #{picked_team}"
                pp(@teams)
                # @teams.select{ |team| team[:drafted_by].nil? && team[:display_name].downcase.include?(pick.downcase) }[0].replace(picked_team[0])
                # pp(@teams)
                result = true
            else
                event.respond("No match, #{pick} matched zero teams... wrong name or has been drafted")
            end
            result
        end

        def mlb_draft_teams
            [
                {:drafted_by=>nil, :round_drafted=>0, :display_name=>"Arizona Diamondbacks"},
                {:drafted_by=>nil, :round_drafted=>0, :display_name=>"Atlanta Braves"},
                {:drafted_by=>nil, :round_drafted=>0, :display_name=>"Baltimore Orioles"},
                {:drafted_by=>nil, :round_drafted=>0, :display_name=>"Boston Red Sox"},
                {:drafted_by=>nil, :round_drafted=>0, :display_name=>"Chicago Cubs"},
                {:drafted_by=>nil, :round_drafted=>0, :display_name=>"Chicago White Sox"},
                {:drafted_by=>nil, :round_drafted=>0, :display_name=>"Cincinnati Reds"},
                {:drafted_by=>nil, :round_drafted=>0, :display_name=>"Cleveland Indians"},
                {:drafted_by=>nil, :round_drafted=>0, :display_name=>"Colorado Rockies"},
                {:drafted_by=>nil, :round_drafted=>0, :display_name=>"Detroit Tigers"},
                {:drafted_by=>nil, :round_drafted=>0, :display_name=>"Houston Astros"},
                {:drafted_by=>nil, :round_drafted=>0, :display_name=>"Kansas City Royals"},
                {:drafted_by=>nil, :round_drafted=>0, :display_name=>"Los Angeles Angels"},
                {:drafted_by=>nil, :round_drafted=>0, :display_name=>"Los Angeles Dodgers"},
                {:drafted_by=>nil, :round_drafted=>0, :display_name=>"Miami Marlins"},
                {:drafted_by=>nil, :round_drafted=>0, :display_name=>"Milwaukee Brewers"},
                {:drafted_by=>nil, :round_drafted=>0, :display_name=>"Minnesota Twins"},
                {:drafted_by=>nil, :round_drafted=>0, :display_name=>"New York Mets"},
                {:drafted_by=>nil, :round_drafted=>0, :display_name=>"New York Yankees"},
                {:drafted_by=>nil, :round_drafted=>0, :display_name=>"Oakland Athletics"},
                {:drafted_by=>nil, :round_drafted=>0, :display_name=>"Philadelphia Phillies"},
                {:drafted_by=>nil, :round_drafted=>0, :display_name=>"Pittsburgh Pirates"},
                {:drafted_by=>nil, :round_drafted=>0, :display_name=>"San Diego Padres"},
                {:drafted_by=>nil, :round_drafted=>0, :display_name=>"San Francisco Giants"},
                {:drafted_by=>nil, :round_drafted=>0, :display_name=>"Seattle Mariners"},
                {:drafted_by=>nil, :round_drafted=>0, :display_name=>"St. Louis Cardinals"},
                {:drafted_by=>nil, :round_drafted=>0, :display_name=>"Tampa Bay Rays"},
                {:drafted_by=>nil, :round_drafted=>0, :display_name=>"Texas Rangers"},
                {:drafted_by=>nil, :round_drafted=>0, :display_name=>"Toronto Blue Jays"},
                {:drafted_by=>nil, :round_drafted=>0, :display_name=>"Washington Nationals"}
            ]
        end
    end
end