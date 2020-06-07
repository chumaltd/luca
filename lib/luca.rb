require "luca/version"


module Luca

  autoload :IO, "luca/io"
  autoload :Code, "luca/code"
  autoload :Mail, "luca/mail"

  class Error < StandardError; end
  # Your code goes here...
end
