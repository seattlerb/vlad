# -*- ruby -*-

require 'rubygems'
require 'hoe'
$: << 'lib'
require 'vlad'

Hoe.new('vlad', Vlad::VERSION) do |p|
  p.rubyforge_name = 'vlad'
  p.author = ["Ryan Davis", "Eric Hodel", "Wilson Bilkovich"]
  p.email = "ryand-ruby@zenspider.com"
  p.url = "http://rubyhitsquad.com/"
  p.summary = 'Vlad the Deployer is pragmatic application deployment automation, without mercy. Impale your application on the heartless spike of the Deployer.'
  p.description = p.paragraphs_of('README.txt', 2..5).join("\n\n")
  p.changes = p.paragraphs_of('History.txt', 0..1).join("\n\n")
  p.extra_deps << 'rake'
  p.extra_deps << 'open4'
end

task :flog do
  sh 'find lib -name \*.rb | grep -v vlad_tasks | xargs flog | head -1'
end

task :flog_full do
  sh 'find lib -name \*.rb | xargs flog -a'
end

# vim: syntax=Ruby
