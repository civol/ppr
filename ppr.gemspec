# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'ppr/version'

Gem::Specification.new do |spec|
  spec.name          = "ppr"
  spec.version       = Ppr::VERSION
  spec.authors       = ["Lovic Gauthier"]
  spec.email         = ["lovic@ariake-nct.ac.jp"]

  spec.summary       = %q{Preprocessor in Ruby: text preprocessor where macros are specified in Ruby language.}
  spec.description   = %q{Preprocessor in Ruby: provides a Ruby class named Rpp which implements a text preprocessor where macros are specified in Ruby language.
 Usage:
 ppr = Ppr::Preprocessor.new(<configuration options if any>) ;
 ppr.preprocess(<input stream to preprocess>, <output stream where to write the preprocessing result>)}
  spec.homepage      = "https://github.com/civol"
  spec.license       = "MIT"

  # Prevent pushing this gem to RubyGems.org. To allow pushes either set the 'allowed_push_host'
  # to allow pushing to a single host or delete this section to allow pushing to any host.
  # if spec.respond_to?(:metadata)
  #   spec.metadata['allowed_push_host'] = "TODO: Set to 'http://mygemserver.com'"
  # else
  #   raise "RubyGems 2.0 or newer is required to protect against " \
  #     "public gem pushes."
  # end

  spec.files         = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", ">= 2.2.10"
  spec.add_development_dependency "rake", ">= 12.3.3"
  spec.add_development_dependency "minitest", ">= 12.3.3"
end
