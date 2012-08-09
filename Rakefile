#!/usr/bin/ruby
# vim:set fileencoding=utf-8 :

desc "test"
task :default => [:test]

desc "minitest"
task "test" do
  sh 'ruby -I. aozora-parser_test.rb'
end
