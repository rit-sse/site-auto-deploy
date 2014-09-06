require 'sinatra'
require 'jekyll'
require 'json'
require 'netaddr'
require 'net/http'
require 'socket'
require  'yaml'
require 'bundler/setup'
require 'mail'
require 'dotenv'
require 'openssl'
Dotenv.load

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
  set :hooks, config['hooks']

  dir = "./pids/"
  file = dir + "sinatra"
  Dir.mkdir(dir) unless File.exists?(dir)
  if File.exists?(file)
    File.delete(file)
  end
  File.open(file, 'w+') do |f|
    f.write(Process.pid.to_s)
  end
  Mail.defaults do
    delivery_method :smtp, address: "smtp-server.rit.edu", port: 25
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

  body = request.body.read
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
  verify_signature(body)
  body = JSON.parse(body)
  if( request.env['HTTP_X_GITHUB_EVENT'] == 'push' and settings.hooks.include?({body['repository']['name'] => body['ref']}) )
    puts "Starting Deploy..."
    Bundler.with_clean_env do
      # Get the deps
      Dir.chdir('/web') do
        system 'git pull'
        system 'git submodule update --remote'
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
        FileUtils.rm_r('assets/images/pages', force: true)
        FileUtils.cp_r('pages/images/.', 'assets/images/pages')

        FileUtils.rm_r('assets/images/posts', force: true)
        FileUtils.cp_r('_posts/images/.', 'assets/images/posts')
        puts "Building site..."
        success = system "jekyll build --source #{settings.src_dir} --destination /tmp/#{body['head_commit']['id']}"
        if(success)
          FileUtils.rm_r(Dir.glob("#{settings.deploy_dir}/*"))
          FileUtils.cp_r("/tmp/#{body['head_commit']['id']}/.", settings.deploy_dir)
        else
          Mail.deliver do
            from     'noreply@sse.se.rit.edu'
            to       body["pusher"]["email"]
            subject  'The site failed to build'
            body     "Your most recent push to the website didn't properly build. Test it locally and fix your mistake."
          end
        end
        Dir.chdir('governing-docs') do
          system "git checkout ."
        end
      end
    end
  end

  # KK we good
  "ok"
end

# Verify that it's from github
def verify_signature(payload_body)
  signature = 'sha1=' + OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new('sha1'), ENV['WEBHOOK_SECRET_TOKEN'], payload_body)
  return halt 500, "Signatures didn't match!" unless Rack::Utils.secure_compare(signature, request.env['HTTP_X_HUB_SIGNATURE'])
end
