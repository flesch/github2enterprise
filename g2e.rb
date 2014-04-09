#!/usr/bin/ruby

require "optparse"
require "octokit"
require "colorize"

load "config.rb"

optparse = OptionParser.new do |opts|

  opts.banner = "GitHub:Enterprise Issue Mirror"

  opts.on("Unsubscribe each user from GitHub:Enterprise notifications", "--notifications") do
    @config[:notifications] = true
  end

  opts.on("Mirror GitHub.com Milestones to GitHub:Enterprise", "--milestones") do
    @config[:milestones] = true
  end

  opts.on("Mirror GitHub.com Labels to GitHub:Enterprise", "--labels") do
    @config[:labels] = true
  end

  opts.on("-i", "--issues ISSUES", "Mirror GitHub.com ISSUES to GitHub:Enterprise") do |issues|
    @config[:issues] = issues
  end

  opts.on("-v", "--verbose", "Enable verbose logging.") do
    @config[:verbose] = true
  end

  opts.on("Run this script in test mode.", "--test") do
    @config[:test] = true
  end

  opts.on("-d", "--delay DELAY", "Wait DELAY seconds between each API interaction.") do |delay|
    @config[:delay] = delay.to_i
  end

  opts.on("This help dialog. See 'config.rb' for additional configuration.", "--help") do
    puts opts
    exit
  end

end

optparse.parse!

puts " > ".light_white.on_blue + "GitHub Mirror ".black.on_blue

if @config[:username].nil? or @config[:password].nil?
  puts "Woah, hold up! I need your GitHub.com username and password.".red
  exit
end

if @config[:delay].nil?
  @config[:delay] = 0
end

puts "No worries, we're running in test mode...".light_yellow if @config[:test]

if @config[:test].nil?
  puts "Warning:".black.on_yellow + " You're not in test mode!".yellow
  print "Are you sure you want to mirror '" + @config[:source].light_blue + "' to '" + @config[:mirror].light_blue + "'? [yes|no] "
  live = gets.chomp.downcase.chars.first
  if not live === "y"
    puts "Ok, cancelling the mirror.".red
    exit
  else
    puts "Ok, here we go!".green
  end
end

if @config[:verbose]
  stack = Faraday::RackBuilder.new do |builder|
    builder.response :logger
    builder.use Octokit::Response::RaiseError
    builder.adapter Faraday.default_adapter
  end
end

# Create a connection to the public GitHub.com API.
client = Octokit::Client.new({
  :login => @config[:username],
  :password => @config[:password],
  :auto_paginate => true,
})
client.middleware = stack unless @config[:verbose].nil?

# Create a connection to the GitHub:Enterprise API for each collaborator.
@config[:collaborators].each do |username, collaborator|
  collaborator[:client] = Octokit::Client.new({
    :login => username == "ghost" ? "deleted-user" : username,
    :password => collaborator[:token],
    :api_endpoint => "https://#{@config[:enterprise]}/api/v3",
    :web_endpoint => "https://#{@config[:enterprise]}/",
    :auto_paginate => true,
  })
  collaborator[:client].middleware = stack unless @config[:verbose].nil?
end

# Ignore any activity on the repo and prevent emails from being sent.
if @config[:notifications]
  puts "· NOTIFICATIONS | #{@config[:mirror]}".light_blue
  @config[:collaborators].each do |username, collaborator|
    if not @config[:test]
      subscription = collaborator[:client].update_subscription(@config[:mirror], { :ignored => true })
    end
    if @config[:test] or subscription[:ignored]
      puts "✖ Ignored '#{@config[:mirror]}' notifications for #{username}.".red
    end
    sleep @config[:delay]
  end
end

if @config[:milestones]

  puts "· MILESTONES | #{@config[:source]} --> #{@config[:mirror]}".light_blue

  milestones = client.list_milestones(@config[:source], { :state => "open" })
  milestones.concat(client.list_milestones(@config[:source], { :state => "closed" }))
  milestones.sort_by! { |milestone| milestone[:number].to_int }

  # Find a milestone in our list of milestones based off its number.
  def get_milestone_by_number(milestones, n)
    milestones.each do |milestone|
      return milestone if milestone[:number] === n
    end
    return nil
  end

  # Create milestones (and delete if necessary)
  (1..milestones.last[:number]).each do |n|

    milestone = get_milestone_by_number(milestones, n)

    if milestone
      puts "✓ Creating milestone '##{n} - #{milestone[:title]}' (as #{milestone[:creator][:login]}).".green
      if not @config[:test]
        collaborator = @config[:collaborators][milestone[:creator][:login]]
        collaborator[:client].create_milestone(@config[:mirror], milestone[:title], {
          :description => milestone[:description],
          :due_on => milestone[:due_on],
          :state => milestone[:state]
        })
      end
    else
      puts "✖ Creating and deleting milestone '##{n}' (as #{@config[:admin]})".red
      if not @config[:test]
        collaborator = @config[:collaborators][@config[:admin]]
        collaborator[:client].create_milestone(@config[:mirror], "#{n}")
        collaborator[:client].delete_milestone(@config[:mirror], n)
      end
    end

    sleep @config[:delay]

  end

  puts "\a✓ All '#{@config[:source]}' milestones have been mirrored to '#{@config[:mirror]}'!\n".yellow

end

if @config[:labels]

  puts "· LABELS | #{@config[:source]} --> #{@config[:mirror]}".light_blue

  labels = client.labels(@config[:source])
  labels.each do |label|
    puts "✓ Creating label '#{label[:name]}' (##{label[:color]}) (as #{@config[:admin]}).".green
    if not @config[:test]
      collaborator = @config[:collaborators][@config[:admin]]
      collaborator[:client].add_label(@config[:mirror], label[:name], label[:color])
    end
    sleep @config[:delay]
  end

  puts "\a✓ All '#{@config[:source]}' labels have been mirrored to '#{@config[:mirror]}'!\n".yellow

end

if @config[:issues]

  puts "· ISSUES | #{@config[:source]} --> #{@config[:mirror]}".light_blue

  #issues = client.issues(@config[:source], { :state => "open" })
  #issues.concat(client.issues(@config[:source], { :state => "closed" }))
  #issues.sort_by! { |issue| issue[:number].to_int }
  #issues = (1..issues.last[:number])
  #sleep @config[:delay]

  issues = @config[:issues].split('-')
  if issues.length === 2
    issues = (issues.shift.to_i..issues.pop.to_i)
  else
    issues = @config[:issues].split(',')
  end

  issues.each do |n|
    n = n.to_i unless n.is_a?(Integer)

    issue = client.issue(@config[:source], n)

    meta = {}
    meta[:labels] = issue[:labels].map! { |label| label[:name] }.join(',') unless issue[:labels].empty?
    meta[:assignee] = issue[:assignee][:login] unless issue[:assignee].nil?
    meta[:milestone] = issue[:milestone][:number] unless issue[:milestone].nil?

    issue[:body] += "\n\n> This issue was migrated from **#{@config[:source]}**. The original issue was opened on **#{issue[:created_at]}**"
    issue[:body] += " and closed on **#{issue[:closed_at]}**" unless issue[:closed_at].nil?
    issue[:body] += "."

    puts "✓ Opening issue '##{issue[:number]} - #{issue[:title]}' (as #{issue[:user][:login]}).".green

    if not issue[:pull_request][:url].nil?
      issue[:body] += " This issue was also converted to a **Pull Request** with these commits:"
      commits = client.pull_request_commits(@config[:source], issue[:number])
      commits.each do |commit|
        puts "  + Adding commit '#{commit[:sha]}' to issue body.".light_green
        issue[:body] += "\n> * #{commit[:sha]}: #{commit[:commit][:message]} (#{commit[:committer][:login]})" unless commit[:committer].nil?
        issue[:body] += "\n> * #{commit[:sha]}: #{commit[:commit][:message]}" if commit[:committer].nil?
      end
    end

    if not @config[:test]
      collaborator = @config[:collaborators][issue[:user][:login]]
      mirror = collaborator[:client].create_issue(@config[:mirror], issue[:title], issue[:body], meta)
    end

    sleep @config[:delay]

    if not issue[:pull_request][:url].nil?
      puts "  + Adding 'pull-request' label to issue.".light_green
      if not @config[:test] and not mirror.nil?
        collaborator = @config[:collaborators][@config[:admin]]
        mirror = collaborator[:client].add_labels_to_an_issue(@config[:mirror], mirror[:number], ["pull-request"])
      end
      sleep @config[:delay]
    end

    puts "  + Adding 'mirror' label to issue.".light_green
    if not @config[:test] and not mirror.nil?
      collaborator = @config[:collaborators][@config[:admin]]
      mirror = collaborator[:client].add_labels_to_an_issue(@config[:mirror], mirror[:number], ["mirror"])
    end
    sleep @config[:delay]

    comments = client.issue_comments(@config[:source], issue[:number])
    comments.each do |comment|
      puts "  ✓ Commenting on issue ##{issue[:number]} (as #{comment[:user][:login]})".light_green
      puts "      \"#{comment[:body][0..30].gsub(/\s\w+\s*$/, '...')}\"".light_white
      comment[:body] += "\n\n> Original comment posted on **#{comment[:created_at]}**."
      if not @config[:test] and not mirror.nil?
        collaborator = @config[:collaborators][comment[:user][:login]]
        collaborator[:client].add_comment(@config[:mirror], mirror[:number], comment[:body])
      end
      sleep @config[:delay]
    end

    puts "  ✖ Closing issue '##{issue[:number]} - #{issue[:title]}' (as #{issue[:closed_by][:login]}).".red unless issue[:closed_by].nil?
    puts "  ✖ Closing issue '##{issue[:number]} - #{issue[:title]}' (as #{@config[:admin]}).".red if issue[:closed_by].nil? and issue[:state] == "closed"
    if not @config[:test] and issue[:state] == "closed"
      collaborator = @config[:collaborators][issue[:closed_by][:login]] unless issue[:closed_by].nil?
      collaborator = @config[:collaborators][@config[:admin]] if issue[:closed_by].nil?
      collaborator[:client].close_issue(@config[:mirror], mirror[:number]) unless mirror.nil?
    end

    sleep @config[:delay]

  end

  puts "\a✓ All '#{@config[:source]}' issues have been mirrored to '#{@config[:mirror]}'!\n".yellow

end
