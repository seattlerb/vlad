# -*- ruby -*-

require 'rubygems'
require 'hoe'
$: << 'lib'
require 'vlad'

Hoe.new('vlad', Vlad::VERSION) do |p|
  p.rubyforge_name = 'hitsquad'
  p.author = ["Ryan Davis", "Eric Hodel", "Wilson Bilkovich"]
  p.email = "ryand-ruby@zenspider.com"
  p.url = p.paragraphs_of('README.txt', 0).first.split(/\n/).map { |s| s.strip }[2..-1]
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

Vlad.load :config => 'foo.rb', :scm => :perforce

# vim: syntax=Ruby
