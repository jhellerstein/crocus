# Prefer code from local source tree to any version in RubyGems
$:.unshift File.join(File.dirname(__FILE__), "..", "lib")

require 'crocus'
require 'test/unit'
require 'rubygems'
