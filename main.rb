require 'sinatra'
require 'jekyll'
require 'JSON'

post '/' do
  body = JSON.parse request.body.read
  user_agent = request.user_agent

  if user_agent =~ /^GitHub Hookshot/ and body["ref"] == "refs/heads/master"
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
      'destination' => '/Users/michael/test-site/'
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