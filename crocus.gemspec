Gem::Specification.new do |s|
  s.name = "crocus"
  s.version = "0.0.1"
  s.date = "2011-07-01"
  s.authors = ["Joseph M. Hellerstein"]
  s.email = ["bloomdevs@gmail.com"]
  s.summary = "A second prototype Bloom DSL for distributed programming."
  s.homepage = "http://www.bloom-lang.org"
  s.description = "A second prototype of the Bloom distributed programming language, as a Ruby DSL."
  s.license = "BSD"
  s.has_rdoc = true
  s.required_ruby_version = '~> 1.9'
  s.rubyforge_project = 'bloom-lang'

  s.files = Dir['lib/**/*'] + Dir['bin/*'] + Dir['docs/**/*'] + Dir['examples/**/*'] + %w[README LICENSE]
  # s.executables = %w[rebl budplot budvis budtimelines]
  # s.default_executable = 'rebl'

  # s.add_dependency 'eventmachine'
end
