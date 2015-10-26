# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'nbu_currency/version'

Gem::Specification.new do |spec|
  spec.name          = "nbu_currency"
  spec.version       = NbuCurrency::VERSION
  spec.authors       = ["Nazar Matus"]
  spec.email         = ["funkyloverone@gmail.com"]

  spec.summary       = %q{Calculates exchange rates based on rates from National Bank of Ukraine. Money gem compatible.}
  spec.description   = %q{This gem reads exchange rates from the National Bank of Ukraine website. It uses it to calculates exchange rates. It is compatible with the money gem.}
  spec.homepage      = "https://github.com/FunkyloverOne/nbu_currency"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  if spec.respond_to?(:metadata)
  end

  spec.add_dependency "nokogiri", "~> 1.6.3"
  spec.add_dependency "money", "~> 6.5.0"
end
