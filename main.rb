require 'sinatra'
require 'jekyll'
require 'json'
require 'netaddr'
require 'net/http'
require 'socket'
require  'yaml'
require 'bundler/setup'

# Set up and globals and process things
configure do
  config = YAML.load_file ".config.yml"
  unless config["deploy_dir"].nil?
    set :deploy_dir, config["deploy_dir"]
  else
    set :deploy_dir, "/_site"
  end

  unless config["src_dir"].nil?
    set :src_dir, config["src_dir"]
  else
    set :src_dir, '/web'
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

  puts "Your site will deploy to #{settings.deploy_dir}"
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
  if netmask.contains?(request.ip) and user_agent =~ /^GitHub Hookshot/
    puts request.env
    if (request.env['HTTP_X_GITHUB_EVENT'] == 'push' and body['ref'] == 'refs/heads/master') or request.env['HTTP_X_GITHUB_EVENT'] == 'release'
      puts "Starting Deploy..."
      Bundler.with_clean_env do
        # Get the deps
        Dir.chdir('/web') do
          system 'git pull'
          system 'git submodule foreach git pull origin master'
          Dir.chdir('governing-docs') do
            system 'git pull origin master'
          end
          system 'bundle install'
          system 'npm install'

          Dir.chdir('governing-docs') do
            constitution = File.open('constitution.md').read
            popol = File.open('primary-officers-policy.md').read
            constitution = "---\nlayout: page\ntitle: \nsidebars: _constitution.html\npermalink: constitution/\n---\n#{constitution}"
            popol = "---\nlayout: page\ntitle: \nsidebars:\n- _constitution.html\npermalink: primary-officers-policy/\n---\n#{popol}"

            File.open('constitution.md', 'w') {|f| f.write(constitution)}
            File.open('primary-officers-policy.md', 'w'){|f| f.write(popol)}
          end

          puts "Building site..."
          system "jekyll build --source #{settings.src_dir} --destination #{settings.deploy_dir}"
          Dir.chdir('governing-docs') do
            system "git checkout ."
          end
        end
      end
    end
  end

  # KK we good
  "ok"
end
