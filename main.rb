require 'sinatra'
require 'jekyll'
require 'JSON'
require 'netaddr'
require 'net/http'

# Set up and globals
configure do
  set :DEPLOY_DIR, "/User/michael/test-site"

  # This is slow and probably not needed
  puts "Getting address information..."
  ip = Net::HTTP.get(URI.parse('http://ifconfig.me/ip'))
  host = Net::HTTP.get(URI.parse('http://ifconfig.me/host'))

  ip.delete!("\n")
  host.delete!("\n")

  puts "Have your webhook point to #{host}:#{settings.port} - #{ip}:#{settings.port}"
  puts "Your site will deploy to #{settings.DEPLOY_DIR}"

end

post '/' do

  body = JSON.parse request.body.read
  user_agent = request.user_agent

  check_ip = Net::HTTP.get(URI.parse('https://api.github.com/meta'))
  valid_ips = JSON.parse(check_ip)
  mask = valid_ips["hooks"]
  puts mask
  netmask = NetAddr::CIDR.create(mask)

  # Make sure it's github!
  if netmask.contains?(request.ip) and user_agent =~ /^GitHub Hookshot/ and body["ref"] == "refs/heads/master"
    puts "Starting Deplay"

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
    Jekyll::Site.new(conf).process

    # Let's get out of here.
    Dir.chdir("/tmp")

    # Get the extra stuff out
    FileUtils.rm_rf(tmpdir)

  end

  # KK we good
  "ok"
end
