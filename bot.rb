require 'discordrb'
require 'pp'
require_relative 'break.rb'
require_relative 'draft.rb'
require_relative 'giveaway.rb'

sessions = {}

bot = Discordrb::Bot.new(
    token: ENV["breakerbot_token"],
    # log_mode: :verbose
)

puts "This bot's invite URL is #{bot.invite_url}."

bot.message(with_text: '!joke') do |event|
    event.message.create_reaction('suschicken:909224511310815333')
end

bot.message(with_text: '!coin') do |event|
    # event.server.emoji.each do |o|
    #     pp(o[1].to_reaction)
    # end
    coin = Random.new
    flip = coin.rand(1..2)
    case flip
    when 1
        event.respond('> **heads**')
    when 2
        event.respond('> **tails**')
    end
end

bot.message(contains: '!AskLansman') do |event|
    # event.server.emoji.each do |o|
    #     pp(o[1].to_reaction)
    # end

    if event.message.content.length < "!AskLansman ".length
        event.respond("You have to ask me something!")
    else
    
        coin = Random.new
        flip = coin.rand(1..3)
        case flip
        when 1
            event.respond('According to Lansman: should be $80')
        when 2
            event.respond('According to Lansman: garbage')
        when 3
            event.respond('According to Lansman: Lansman Approved')
        end
    end
end

bot.message(with_text: '!draft') do |event|
    sessions[event.author.username] = {
        type: :draft,
        state: 0,
        server: event.server,
        event_channel: event.channel.name
    }
    draft = BreakerBot::Draft.new(bot, event, sessions[event.author.username])    
    draft.start
end

bot.message(with_text: '!giveaway') do |event|
    sessions[event.author.username] = {
        type: :giveaway,
        state: 0,
        server: event.server,
        event_channel: event.channel.name
    }
    giveaway = BreakerBot::Giveaway.new(bot, event, sessions[event.author.username])    
    giveaway.start
end

bot.message(with_text: '!break') do |event|
    sessions[event.author.username] = {
        type: :break,
        state: 0,
        server: event.server,
        available_rooms: break_announcement_rooms(event.server)
    }
    b = BreakerBot::Break.new(bot, event, sessions[event.author.username])
    
    b.start
end

def break_channel_categories(server)
    server.channels.select{ |c| c.name.downcase.include?('room') && c.type == Discordrb::Channel::TYPES[:category] }
end

def break_announcement_rooms(server)
    server.channels.select{ |c| c.name.include?('announcement') && c.type == Discordrb::Channel::TYPES[:text] && break_channel_categories(server).any? { |cat| cat.id == c.parent_id } }
end

bot.run
