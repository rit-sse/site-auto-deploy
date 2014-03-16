require 'sinatra'
require 'jekyll'
require 'json'
require 'netaddr'
require 'net/http'
require 'socket'
require  'yaml'

# Set up and globals and process things
configure do
  config = YAML.load_file ".config.yml"
  if config["DEPLOY_DIR"] != nil
    set :DEPLOY_DIR, config["DEPLOY_DIR"]
  else
    set :DEPLOY_DIR, "~/_site"
  end

  dir = "./pids/"
  file = dir + "sinatra"
  Dir.mkdir(dir) unless File.exists?(dir)
  if File.exists?(file)
    File.delete(file)
  end
  File.open(file, 'w+') do |f|
    f.write(Process.pid.to_s)
  end

  puts "Your site will deploy to #{settings.DEPLOY_DIR}"
end

Signal.trap("USR1") do
  puts "Restart? Lol"
end

Signal.trap("INT") do
  puts "[Crazytrain Daemon] Shutting down..."
  if File.exists?("./pids/sinatra")
    File.delete("./pids/sinatra")
  end
end

# The bit that make it happen
post '/' do

  body = JSON.parse request.body.read
  user_agent = request.user_agent
  url = URI.parse('https://api.github.com/meta')
  http = Net::HTTP.new(url.host, url.port)
  http.use_ssl = true
  check_ip = http.get('/meta').body
  valid_ips = JSON.parse(check_ip)
  mask = valid_ips["hooks"][0]
  puts mask
  netmask = NetAddr::CIDR.create(mask)

  # Make sure it's github!
  if netmask.contains?(request.ip) and user_agent =~ /^GitHub Hookshot/ and body["ref"] == "refs/heads/master"
    puts "Starting Deploy..."

    # To the temp dir! And clone
    tmpdir = "/tmp/" + body["after"]
    system "git clone https://github.com/rit-sse/crazy-train.git #{tmpdir}"
    Dir.chdir(tmpdir)


    # Get the deps
    system "bundle install"
    system "npm install"

    # Build the site
    conf = Jekyll.configuration({
      'source'      => tmpdir,
      'destination' => settings.DEPLOY_DIR
    })
    puts "Building site..."
    Jekyll::Site.new(conf).process

    # Let's get out of here.
    Dir.chdir("/tmp")

    # Get the extra stuff out
    FileUtils.rm_rf(tmpdir)

  end

  # KK we good
  "ok"
end
