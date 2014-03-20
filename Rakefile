desc 'pull all the things'
task :setup do
  Dir.chdir('/web') do
    sh 'git pull'
    Dir.chdir('/governing-docs') do
      sh 'git pull origin master'
    end
    sh 'bundle install'
    sh 'npm install'
  end
end

namespace :govdocs do
  task :jekyllify, :src do |t, args|
    Dir.chdir("/#{args[:src]}/governing-docs") do
      constituion = File.open('constitution.md').read
      popol = File.open('primary-officers-policy.md').read
      constitution = "---\nlayout: page\ntitle: \nsidebars: _constitution\n---\n#{constitution}"
      popol = "---\nlayout: page\ntitle: \nsidebars:\n- _constitution\n---\n#{popol}"

      File.open('constitution.md', 'w').puts(constitution)
      File.open('primary-officers-policy', 'w').puts(popol)
    end
  end

  task :unjekyllify, :src do |t, args|
    Dir.chdir("/#{args[:src]}/governing-docs") do
      sh 'git checkout .'
    end
  end
end